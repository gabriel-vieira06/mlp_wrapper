#!/usr/bin/env python3
"""Check each supported topology with independent synthetic fixed-point scores.

Run with Python that has the Verilator package installed:
    /workspace/mlp-env/bin/python tests/run_topology_tests.py

All temporary weights, biases, inputs, builds and logs stay outside the checkout.
Synthetic memories are test fixtures only, never substitutes for trained weights.
Each actual variant's mlp.v adapter is exercised. The single-hidden-layer 256
case also stalls output readiness and checks that the beat remains stable.
"""

from __future__ import annotations

import argparse
from pathlib import Path
import re
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
BASE_RTL = REPO / "Vivado/updated_mlp_wrapper.srcs/sources_1/new"
DEFAULT_WRAPPER = REPO / "Vivado/topologies/common/mlp_topology.sv"
TOPOLOGIES = {
    "500_500": (500, 500),
    "256_128": (256, 128),
    "256": (256,),
    "512_256_128": (512, 256, 128),
}
MASK32 = (1 << 32) - 1
MASK64 = (1 << 64) - 1
SCALE = 1 << 22


def signed32(value: int) -> int:
    return value - (1 << 32) if value & (1 << 31) else value


def write_mem(path: Path, values: list[int]) -> None:
    with path.open("w") as stream:
        stream.writelines(f"{value & MASK32:08x}\n" for value in values)


def layer_memories(inputs: int, outputs: int, layer: int, final: bool):
    """A sparse but nonzero matrix exercises every output neuron and its index."""
    weights = []
    for output in range(outputs):
        row = [0] * inputs
        indices = (output % inputs,
                   (output*7 + inputs//2 + layer) % inputs,
                   (output*13 + inputs - 1) % inputs)
        coefficients = (SCALE, -SCALE//2, SCALE//4)
        if final and output % 3 == 0:
            coefficients = (-SCALE, -SCALE//2, -SCALE//4)
        elif not final and output % 5 == 0:
            coefficients = (-SCALE, -SCALE//2, SCALE//4)
        for index, coefficient in zip(indices, coefficients, strict=True):
            row[index] += coefficient
        weights.append(row)
    # Include both raw positive and negative bias words. The existing dense
    # implementation zero-extends this unsigned port before shifting by P_INT;
    # reproducing that quirk is necessary to preserve its current arithmetic.
    biases = [((1 if (output + layer) % 2 else -1) *
               ((output % 5) + 1) * (1 << 20)) & MASK32
              for output in range(outputs)]
    return weights, biases


def dense_reference(values, weights, biases, relu: bool):
    result = []
    for row, bias in zip(weights, biases, strict=True):
        accumulator = (sum(signed32(x) * weight
                           for x, weight in zip(values, row, strict=True)) +
                       (bias << 10)) & MASK64
        if relu and accumulator & (1 << 63):
            accumulator = 0
        # Match dense.sv's [(WIDTH*2-1)-P_INT -: WIDTH] slice, not rounding.
        result.append((accumulator >> 22) & MASK32)
    return result


def prepare_fixtures(directory: Path, hidden: tuple[int, ...], frames: int):
    sizes = (784, *hidden, 10)
    matrices = []
    for layer, (inputs, outputs) in enumerate(zip(sizes, sizes[1:]), 1):
        weights, biases = layer_memories(inputs, outputs, layer, layer == len(sizes)-1)
        write_mem(directory / f"H{layer}W.mem", [x for row in weights for x in row])
        write_mem(directory / f"H{layer}B.mem", biases)
        matrices.append((weights, biases))
    inputs = [[(((pixel*17 + frame*29) % 67) - 20) * (1 << 17) & MASK32
               for pixel in range(784)] for frame in range(frames)]
    write_mem(directory / "synthetic_inputs.mem", [x for frame in inputs for x in frame])
    expected = []
    for values in inputs:
        for layer, (weights, biases) in enumerate(matrices):
            values = dense_reference(values, weights, biases, layer < len(matrices)-1)
        expected.extend(values)
    if not any(signed32(x) < 0 for x in expected) or not any(signed32(x) > 0 for x in expected):
        raise RuntimeError("Synthetic fixture must exercise positive and negative logits")
    if frames > 1 and expected[:10] == expected[10:20]:
        raise RuntimeError("Synthetic fixtures must produce different frame outputs")
    write_mem(directory / "expected_logits.hex", expected)
    return expected


def run(command: list[str], directory: Path, log_name: str) -> str:
    log = directory / log_name
    with log.open("w") as stream:
        result = subprocess.run(command, cwd=directory, stdout=stream,
                                stderr=subprocess.STDOUT, timeout=900, check=False)
    text = log.read_text()
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log}\n{text[-5000:]}")
    return text


def test_topology(name: str, hidden: tuple[int, ...], frames: int,
                  root: Path, wrapper: Path, adapter: Path | None = None,
                  output_stalls: bool = False) -> None:
    directory = root / name
    directory.mkdir()
    expected = prepare_fixtures(directory, hidden, frames)
    padded = (*hidden, 1, 1)[:3]
    parameters = [f"-GHIDDEN_LAYERS={len(hidden)}", f"-GH1_SIZE={padded[0]}",
                  f"-GH2_SIZE={padded[1]}", f"-GH3_SIZE={padded[2]}", f"-GFRAMES={frames}",
                  f"-GUSE_ADAPTER={int(adapter is not None)}",
                  f"-GOUTPUT_STALLS={int(output_stalls)}"]
    sources = [BASE_RTL / name for name in
               ("dense.sv", "mult2c.sv", "ReLU.sv", "hard_sigmoid.sv",
                "hard_tanh.sv", "leakyReLU.sv", "step.sv",
                "mem_behavioral_W.sv", "mem_behavioral_B.sv")]
    if adapter is not None:
        if not adapter.is_file():
            raise ValueError(f"Missing variant adapter: {adapter}")
        sources.append(adapter)
    run([sys.executable, "-m", "verilator", "--binary", "--timing", "-Wno-fatal",
         "-j", "2", "--top-module", "topology_regression_tb", "--Mdir", str(directory / "obj"),
         *parameters, *map(str, sources), str(wrapper),
         str(REPO / "tests/topology_regression_tb.sv")], directory, "build.log")
    summary = run([str(directory / "obj/Vtopology_regression_tb")], directory, "simulation.log")
    match = re.search(r"PASS: (\d+) frames, (\d+) logits, (\d+) cycles, (\d+) stalled cycles", summary)
    if not match or (int(match[1]), int(match[2])) != (frames, frames*10):
        raise RuntimeError(f"Missing complete simulation summary for {name}")
    if output_stalls and int(match[4]) == 0:
        raise RuntimeError(f"Output backpressure was not exercised for {name}")
    actual_text = (directory / "logits.hex").read_text().splitlines()
    if len(actual_text) != len(expected) or any(not re.fullmatch(r"[0-9a-fA-F]{8}", x) for x in actual_text):
        raise RuntimeError(f"Malformed or incomplete logits for {name}")
    actual = [int(word, 16) for word in actual_text]
    for index, (a, b) in enumerate(zip(actual, expected, strict=True)):
        if a != b:
            raise RuntimeError(f"{name}: mismatch at frame {index//10}, output {index%10}: "
                               f"RTL={a:08x}, expected={b:08x}; see {directory}")
    print(f"{name}: PASS — {frames} frames, {len(expected)} bit-exact logits, {match[3]} cycles, "
          f"{match[4]} stalled cycles",
          flush=True)


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--topology", choices=TOPOLOGIES, help="Run one variant (default: all four)")
    parser.add_argument("--frames", type=int, default=2, help="Repeated synthetic frames (default: 2)")
    parser.add_argument("--wrapper", type=Path, default=DEFAULT_WRAPPER)
    args = parser.parse_args()
    if not 1 <= args.frames <= 10:
        parser.error("frames must be 1..10")
    if not args.wrapper.is_file():
        parser.error(f"missing wrapper: {args.wrapper}")
    root = Path(tempfile.mkdtemp(prefix="mlp-topology-tests-"))
    print(f"Synthetic test fixtures and logs: {root}", flush=True)
    selected = {args.topology: TOPOLOGIES[args.topology]} if args.topology else TOPOLOGIES
    for name, hidden in selected.items():
        adapter = REPO / "Vivado/topologies" / name / "mlp.v"
        test_topology(name, hidden, args.frames, root, args.wrapper.resolve(),
                      adapter=adapter, output_stalls=name == "256")
    print(f"PASS: {len(selected)} topology variant(s); trained accuracy was not tested", flush=True)


if __name__ == "__main__":
    main()
