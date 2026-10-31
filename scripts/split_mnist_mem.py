#!/usr/bin/env python3
"""Split the supplied 10,000-image MNIST memories into ten aligned batches.

Usage: python3 scripts/split_mnist_mem.py samples.mem labels.mem output_directory
Each image has 784 hexadecimal 32-bit pixels and one hexadecimal label (0..9).
Source record bytes are preserved, including their original line endings.
"""

from __future__ import annotations

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import tempfile


TOTAL_IMAGES = 10000
IMAGES_PER_BATCH = 1000
PIXELS_PER_IMAGE = 784
SAMPLE_WORD = re.compile(rb"[0-9a-fA-F]{8}")
LABEL_WORD = re.compile(rb"(?:0[xX])?[0-9a-fA-F]+")


def _record(stream, kind: str, index: int) -> bytes:
    raw = stream.readline()
    if not raw:
        raise ValueError(f"Missing {kind} record {index}: input ended early")
    word = raw.rstrip(b"\r\n")
    if kind == "sample":
        valid = SAMPLE_WORD.fullmatch(word) is not None
    else:
        valid = LABEL_WORD.fullmatch(word) is not None and int(word, 16) <= 9
    if not valid:
        raise ValueError(f"Invalid {kind} record {index}")
    return raw


def split_mnist_mem(samples_path: Path, labels_path: Path, output_dir: Path) -> dict:
    samples_path, labels_path, output_dir = map(Path, (samples_path, labels_path, output_dir))
    if output_dir.exists():
        raise FileExistsError(f"Refusing to overwrite existing output: {output_dir}")
    if TOTAL_IMAGES <= 0 or IMAGES_PER_BATCH <= 0 or TOTAL_IMAGES % IMAGES_PER_BATCH:
        raise ValueError("Image count must be a positive multiple of the batch size")
    if PIXELS_PER_IMAGE <= 0:
        raise ValueError("Pixels per image must be positive")
    # Open both inputs before creating any output or staging directory.
    with samples_path.open("rb") as samples, labels_path.open("rb") as labels:
        output_dir.parent.mkdir(parents=True, exist_ok=True)
        staging = Path(tempfile.mkdtemp(prefix=".mnist-batches-", dir=output_dir.parent))
        try:
            source_samples_hash = hashlib.sha256()
            source_labels_hash = hashlib.sha256()
            batches = []
            sample_index = label_index = 0
            for batch_id in range(TOTAL_IMAGES // IMAGES_PER_BATCH):
                sample_name = f"test_samples_{batch_id:02d}.mem"
                label_name = f"test_labels_{batch_id:02d}.mem"
                sample_hash, label_hash = hashlib.sha256(), hashlib.sha256()
                sample_bytes = label_bytes = 0
                with (staging / sample_name).open("wb") as sample_out:
                    for _ in range(IMAGES_PER_BATCH * PIXELS_PER_IMAGE):
                        raw = _record(samples, "sample", sample_index)
                        sample_index += 1
                        sample_out.write(raw)
                        sample_hash.update(raw)
                        source_samples_hash.update(raw)
                        sample_bytes += len(raw)
                with (staging / label_name).open("wb") as label_out:
                    for _ in range(IMAGES_PER_BATCH):
                        raw = _record(labels, "label", label_index)
                        label_index += 1
                        label_out.write(raw)
                        label_hash.update(raw)
                        source_labels_hash.update(raw)
                        label_bytes += len(raw)
                batches.append({
                    "batch_id": batch_id,
                    "first_image": batch_id * IMAGES_PER_BATCH,
                    "last_image": (batch_id + 1) * IMAGES_PER_BATCH - 1,
                    "images": IMAGES_PER_BATCH,
                    "samples": {"file": sample_name,
                                "records": IMAGES_PER_BATCH * PIXELS_PER_IMAGE,
                                "bytes": sample_bytes, "sha256": sample_hash.hexdigest()},
                    "labels": {"file": label_name, "records": IMAGES_PER_BATCH,
                               "bytes": label_bytes, "sha256": label_hash.hexdigest()},
                })
            if samples.read(1):
                raise ValueError(f"Extra sample records after the expected {TOTAL_IMAGES} images")
            if labels.read(1):
                raise ValueError(f"Extra label records after the expected {TOTAL_IMAGES} images")
            manifest = {
                "images": TOTAL_IMAGES,
                "images_per_batch": IMAGES_PER_BATCH,
                "pixels_per_image": PIXELS_PER_IMAGE,
                "source_samples": {"file": samples_path.name, "records": sample_index,
                                   "sha256": source_samples_hash.hexdigest()},
                "source_labels": {"file": labels_path.name, "records": label_index,
                                  "sha256": source_labels_hash.hexdigest()},
                "batches": batches,
            }
            (staging / "manifest.json").write_text(json.dumps(manifest, indent=2) + "\n")
            staging.rename(output_dir)
            return manifest
        finally:
            if staging.exists():
                shutil.rmtree(staging)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("samples", type=Path)
    parser.add_argument("labels", type=Path)
    parser.add_argument("output", type=Path)
    args = parser.parse_args()
    manifest = split_mnist_mem(args.samples, args.labels, args.output)
    print(f"Created {len(manifest['batches'])} paired batches in {args.output}")


if __name__ == "__main__":
    main()
