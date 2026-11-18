"""Run the PYNQ-Z1 MNIST benchmarks with simple-mode AXI DMA."""

import math
from pathlib import Path
import re
from time import perf_counter, sleep

import numpy as np


TOPOLOGIES = ("64-32", "256", "256-128", "500-500", "512-256-128")
BATCH_COUNT = 10
IMAGES_PER_BATCH = 1000
PIXELS = 784
CLASSES = 10
SAMPLE_WORD = re.compile(rb"[0-9a-fA-F]{8}")
LABEL_WORD = re.compile(rb"(?:0[xX])?[0-9a-fA-F]+")

# Keep DMA-accessible memory alive if we could not confirm that DMA stopped.
_unreleased_buffers = []


def _read_words(path, count, pattern, dtype, max_value):
    with path.open("rb") as stream:
        def words():
            for index in range(1, count + 1):
                word = stream.readline().rstrip(b"\r\n")
                if not pattern.fullmatch(word):
                    raise ValueError(f"{path}: missing or invalid hex word at line {index}")
                value = int(word, 16)
                if value > max_value:
                    raise ValueError(f"{path}: value out of range at line {index}")
                yield value

        result = np.fromiter(words(), dtype=dtype, count=count)
        if stream.read(1):
            raise ValueError(f"{path}: expected exactly {count} words")
    return result


def _load_batch(samples_path, labels_path):
    samples = _read_words(
        samples_path, IMAGES_PER_BATCH * PIXELS, SAMPLE_WORD, np.uint32, 0xffffffff
    )
    labels = _read_words(labels_path, IMAGES_PER_BATCH, LABEL_WORD, np.intp, CLASSES - 1)
    return samples.reshape(IMAGES_PER_BATCH, PIXELS), labels


def _check_overlay(overlay):
    dma_info = overlay.ip_dict.get("axi_dma_0", {})
    if not dma_info.get("type", "").startswith("xilinx.com:ip:axi_dma:"):
        raise ValueError("The overlay metadata must describe an AXI DMA named axi_dma_0.")
    params = {name.lower(): value for name, value in dma_info.get("parameters", {}).items()}
    required = {
        "c_include_sg": 0,
        "c_include_mm2s": 1,
        "c_include_s2mm": 1,
        "c_m_axis_mm2s_tdata_width": 32,
        "c_s_axis_s2mm_tdata_width": 32,
    }
    for name, expected in required.items():
        if int(params.get(name, -1)) != expected:
            raise ValueError(f"axi_dma_0 requires {name}={expected}.")
    if int(params.get("c_micro_dma", 0)) != 0:
        raise ValueError("axi_dma_0 must use standard simple DMA, with Micro DMA disabled.")
    length_width = int(params.get("c_sg_length_width", 0))
    if (1 << length_width) - 1 < PIXELS * 4:
        raise ValueError("The DMA transfer length limit is too small for one image.")


def _reset_dma(dma):
    # AXI DMA PG021: setting MM2S_DMACR.Reset resets both channels.
    dma.mmio.write(0x00, 0x04)
    deadline = perf_counter() + 1.0
    while perf_counter() < deadline:
        reset_pending = dma.mmio.read(0x00) & 0x04
        send_halted = dma.mmio.read(0x04) & 0x01
        receive_halted = dma.mmio.read(0x34) & 0x01
        if not reset_pending and send_halted and receive_halted:
            return
        sleep(0.001)
    raise TimeoutError("AXI DMA reset did not complete.")


def _exchange(dma, tx, rx, timeout_s, location):
    send, receive = dma.sendchannel, dma.recvchannel
    start = perf_counter()
    try:
        # The accelerator emits one TLAST after ten scores, so arm RX per image.
        receive.transfer(rx)
        send.transfer(tx)
        while True:
            for name, channel in (("MM2S", send), ("S2MM", receive)):
                if channel.error or not channel.running:
                    raise RuntimeError(f"{name} entered an error or halted state")
            if send.idle and receive.idle:
                break
            if perf_counter() - start >= timeout_s:
                raise TimeoutError(f"DMA did not complete within {timeout_s:g} s")
        send.wait()
        receive.wait()  # PYNQ invalidates the RX cache here.
        if send.transferred != tx.nbytes or receive.transferred != rx.nbytes:
            raise RuntimeError(
                f"Unexpected DMA length: sent {send.transferred}/{tx.nbytes} bytes, "
                f"received {receive.transferred}/{rx.nbytes} bytes"
            )
        return perf_counter() - start
    except BaseException as error:
        _unreleased_buffers.extend((tx, rx))
        try:
            _reset_dma(dma)
        except Exception as reset_error:
            raise RuntimeError(
                f"{location}: {error}. DMA reset failed ({reset_error}). "
                "Reboot the board before running again."
            ) from error
        _unreleased_buffers.clear()
        if not isinstance(error, Exception):
            raise
        message = f"{location}: {error}. Rerun the notebook to reload the overlay."
        if isinstance(error, TimeoutError):
            raise TimeoutError(message) from error
        raise RuntimeError(message) from error


def _metrics(confusion, seconds, latencies):
    images = int(confusion.sum())
    correct = int(confusion.trace())
    return {
        "images": images,
        "correct": correct,
        "accuracy_pct": 100 * correct / images,
        "classification_s": seconds,
        "images_per_s": images / seconds,
        "dma_mean_ms": float(np.mean(latencies) * 1000),
        "dma_median_ms": float(np.median(latencies) * 1000),
        "dma_p95_ms": float(np.percentile(latencies, 95) * 1000),
    }


def validate_on_board(topology, topologies_dir, test_dir, *, timeout_s=2.0, bitstream=None):
    """Program the selected overlay and classify every image in the ten batches.

    Each latency covers DMA submission through transfer completion and RX cache
    invalidation. Batch classification time also includes per-image input copies
    and argmax. Disk reads, overlay programming and the warm-up are excluded.
    Only one application should use the FPGA during a run.
    """
    if _unreleased_buffers:
        raise RuntimeError("A previous DMA reset failed. Reboot the board before running again.")
    if topology not in TOPOLOGIES:
        raise ValueError(f"Unsupported topology {topology!r}. Choose from {', '.join(TOPOLOGIES)}.")
    if not math.isfinite(timeout_s) or timeout_s <= 0:
        raise ValueError("timeout_s must be finite and positive.")

    if bitstream is None:
        bitstream = Path(topologies_dir) / topology / f"mlp_{topology.replace('-', '_')}.bit"
    bitstream = Path(bitstream).expanduser().resolve()
    if bitstream.suffix != ".bit":
        raise ValueError(f"Expected a .bit file: {bitstream}")
    hwh = bitstream.with_suffix(".hwh")
    tcl = bitstream.with_suffix(".tcl")
    test_dir = Path(test_dir).expanduser().resolve()
    batch_paths = [
        (test_dir / f"test_samples_{index:02d}.mem", test_dir / f"test_labels_{index:02d}.mem")
        for index in range(BATCH_COUNT)
    ]
    for path in (bitstream, hwh, *(path for pair in batch_paths for path in pair)):
        if not path.is_file():
            raise FileNotFoundError(f"Required benchmark file missing: {path}")
    first_batch = _load_batch(*batch_paths[0])

    try:
        from pynq import Overlay, allocate
    except ImportError as error:
        raise RuntimeError("Run the benchmark with the PYNQ Python kernel on the board.") from error

    overlay = Overlay(str(bitstream), download=False)
    _check_overlay(overlay)
    start = perf_counter()
    overlay.download()
    overlay_program_s = perf_counter() - start
    dma = overlay.axi_dma_0

    metrics = []
    total_confusion = np.zeros((CLASSES, CLASSES), dtype=np.int64)
    all_latencies = np.empty((BATCH_COUNT, IMAGES_PER_BATCH), dtype=np.float64)
    tx = rx = None
    try:
        tx = allocate(shape=(PIXELS,), dtype=np.uint32)
        rx = allocate(shape=(CLASSES,), dtype=np.int32)
        tx[:] = first_batch[0][0]
        _exchange(dma, tx, rx, timeout_s, "Warm-up (batch 00, image 0)")

        for index, paths in enumerate(batch_paths):
            print(f"Classifying batch {index:02d} ({index + 1}/{BATCH_COUNT})", flush=True)
            samples, labels = first_batch if index == 0 else _load_batch(*paths)
            predicted = np.empty(IMAGES_PER_BATCH, dtype=np.intp)
            latencies = all_latencies[index]
            start = perf_counter()
            for image, pixels in enumerate(samples):
                tx[:] = pixels
                latencies[image] = _exchange(dma, tx, rx, timeout_s, f"Batch {index:02d}, image {image}")
                predicted[image] = np.argmax(rx)
            seconds = perf_counter() - start
            confusion = np.bincount(labels * CLASSES + predicted, minlength=CLASSES ** 2)
            confusion = confusion.reshape(CLASSES, CLASSES)
            total_confusion += confusion
            metrics.append(dict(batch=index, **_metrics(confusion, seconds, latencies)))
    finally:
        if not _unreleased_buffers:
            for buffer in (tx, rx):
                if buffer is not None:
                    buffer.freebuffer()

    overall = _metrics(total_confusion, sum(batch["classification_s"] for batch in metrics), all_latencies)
    return {
        "topology": topology,
        "bitstream": str(bitstream),
        "hwh": str(hwh),
        "tcl": str(tcl) if tcl.is_file() else None,
        "test_dir": str(test_dir),
        "overlay_program_s": overlay_program_s,
        "batches": metrics,
        "overall": overall,
        "confusion_matrix": total_confusion,
    }


def display_report(report):
    """Render batch metrics and the aggregate confusion matrix in Jupyter."""
    from IPython.display import Markdown, display

    print(f"Topology {report['topology']} | FPGA programming {report['overlay_program_s']:.3f} s")
    print(f"Bitstream: {report['bitstream']}")
    print(f"Test batches: {report['test_dir']}")
    lines = [
        "| Batch | Correct / images | Accuracy | Classification (s) | Images/s | DMA mean (ms) | DMA median (ms) | DMA p95 (ms) |",
        "| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |",
    ]
    for row in [*report["batches"], report["overall"]]:
        name = f"{row['batch']:02d}" if "batch" in row else "Overall"
        lines.append(
            f"| {name} | {row['correct']} / {row['images']} | {row['accuracy_pct']:.2f}% | "
            f"{row['classification_s']:.3f} | {row['images_per_s']:.1f} | "
            f"{row['dma_mean_ms']:.3f} | {row['dma_median_ms']:.3f} | {row['dma_p95_ms']:.3f} |"
        )
    lines.extend([
        "",
        "### Confusion matrix",
        "",
        "| True digit ↓ / Predicted → | " + " | ".join(map(str, range(CLASSES))) + " | Class accuracy |",
        "| --- |" + " ---: |" * (CLASSES + 1),
    ])
    for digit, counts in enumerate(report["confusion_matrix"]):
        support = counts.sum()
        accuracy = f"{100 * counts[digit] / support:.2f}%" if support else "—"
        lines.append(f"| {digit} | " + " | ".join(map(str, counts)) + f" | {accuracy} |")
    display(Markdown("\n".join(lines)))
