#!/usr/bin/env python3
"""Run RTL checks, optionally comparing raw logits with a reference RTL tree.

Use the prepared environment, for example:
  /workspace/mlp-env/bin/python tests/run_rtl_tests.py --samples 1000 \
      --reference-rtl /workspace/mlp-baseline/rtl
All generated files are written outside the checkout into a temporary directory.

Golden first-ten-frame logits were generated with the original RTL and committed
H1/H2/H3 weight/bias memory files at repository commit
082e4231fc3b992f18bbbe41aecf70ae052791bb, using N_MULT=1. They preserve
the existing fixed-point arithmetic, rather than floating-point PyTorch results.
"""

from __future__ import annotations

import argparse
import itertools
from pathlib import Path
import re
import subprocess
import sys
import tempfile


REPO = Path(__file__).resolve().parents[1]
RTL = REPO / "Vivado/updated_mlp_wrapper.srcs/sources_1/new"
FIXTURES = REPO / "Vivado/updated_mlp_wrapper.srcs/sim_1/new"
TESTS = REPO / "tests"


def run(command: list[str], cwd: Path, log: Path, timeout: int = 900) -> str:
    with log.open("w") as output:
        result = subprocess.run(
            command, cwd=cwd, stdout=output, stderr=subprocess.STDOUT,
            timeout=timeout, check=False,
        )
    text = log.read_text()
    if result.returncode:
        raise RuntimeError(f"Command failed ({result.returncode}); see {log}\n{text[-4000:]}")
    return text


def build(rtl: Path, target: str, directory: Path, parameters: list[str]) -> Path:
    directory.mkdir(parents=True)
    sources = [rtl / "mult2c.sv"] if target == "mult2c_tb" else sorted(rtl.glob("*.sv"))
    command = [
        sys.executable, "-m", "verilator", "--binary", "--timing", "-Wno-fatal",
        "-j", "2", "--top-module", target, "--Mdir", str(directory / "obj"),
        *parameters, *map(str, sources),
        str(TESTS / f"{target}.sv"),
    ]
    run(command, directory, directory / "build.log")
    return directory / "obj" / f"V{target}"


def prepare_fixtures(directory: Path, samples: int) -> None:
    for name, count in (("test_samples.mem", samples * 784), ("test_labels.mem", samples)):
        with (FIXTURES / name).open() as source:
            lines = list(itertools.islice(source, count))
        if len(lines) != count:
            raise ValueError(f"Fixture {name} has only {len(lines)} of {count} required lines")
        # Verilator rejects readmemh files longer than the destination array.
        (directory / name).write_text("".join(lines))
    for name in ("H1W.mem", "H1B.mem", "H2W.mem", "H2B.mem", "H3W.mem", "H3B.mem"):
        (directory / name).symlink_to(RTL / name)


def simulate(rtl: Path, directory: Path, samples: int, lanes: int) -> list[str]:
    executable = build(
        rtl, "mlp_regression_tb", directory,
        [f"-GNUM_TESTS={samples}", f"-GN_MULT={lanes}"],
    )
    prepare_fixtures(directory, samples)
    text = run([str(executable)], directory, directory / "simulation.log")
    summary = re.search(r"PASS: (\d+) frames, (\d+) logits, (\d+) correct predictions, (\d+) cycles", text)
    if not summary or (int(summary[1]), int(summary[2])) != (samples, samples * 10):
        raise RuntimeError(f"Missing or incomplete simulation summary: {directory / 'simulation.log'}")
    logits = (directory / "logits.hex").read_text().splitlines()
    if len(logits) != samples * 10 or any(not re.fullmatch(r"[0-9a-fA-F]{8}", x) for x in logits):
        raise RuntimeError(f"Invalid logits file: {directory / 'logits.hex'}")
    print(f"{directory.name}: {summary[0]}", flush=True)
    return logits


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--samples", type=int, default=10, help="MNIST frames to exercise (default: 10)")
    parser.add_argument("--n-mult", type=int, default=1, help="Parallel multiplier lanes (default: 1)")
    parser.add_argument("--reference-rtl", type=Path, help="Baseline directory containing dense_wrapper.sv etc.")
    args = parser.parse_args()
    if not 1 <= args.samples <= 10000 or args.n_mult < 1:
        parser.error("samples must be 1..10000 and n-mult must be positive")
    if args.reference_rtl and not (args.reference_rtl / "dense_wrapper.sv").is_file():
        parser.error("reference-rtl must contain dense_wrapper.sv")

    root = Path(tempfile.mkdtemp(prefix="mlp-rtl-tests-"))
    print(f"Logs, builds and logits: {root}", flush=True)
    multiplier_directory = root / "multiplier"
    executable = build(RTL, "mult2c_tb", multiplier_directory, [])
    text = run([str(executable)], multiplier_directory, multiplier_directory / "simulation.log")
    if "PASS: 65536 exhaustive 8-bit and 20064 boundary/random 32-bit products" not in text:
        raise RuntimeError("Missing multiplier test completion summary")
    print("multiplier: PASS (85,600 products)", flush=True)
    actual = simulate(RTL, root / "current", args.samples, args.n_mult)
    if args.n_mult == 1:
        golden = (TESTS / "expected_logits_first10.hex").read_text().splitlines()
        if len(golden) != 100 or any(not re.fullmatch(r"[0-9a-fA-F]{8}", x) for x in golden):
            raise RuntimeError("Invalid first-ten-frame golden logits fixture")
        prefix_length = min(args.samples, 10) * 10
        for index in range(prefix_length):
            if actual[index].lower() != golden[index].lower():
                raise RuntimeError(
                    f"Golden logit mismatch at frame {index // 10}, output {index % 10}: "
                    f"current {actual[index]}, expected {golden[index]}"
                )
        print(f"PASS: first {prefix_length} raw logits match the committed golden fixture", flush=True)
    if args.reference_rtl:
        expected = simulate(args.reference_rtl.resolve(), root / "reference", args.samples, args.n_mult)
        for index, (a, b) in enumerate(zip(actual, expected, strict=True)):
            if a.lower() != b.lower():
                raise RuntimeError(
                    f"Logit mismatch at frame {index // 10}, output {index % 10}: "
                    f"current {a}, reference {b}"
                )
        print(f"PASS: all {len(actual):,} raw logits match the reference bit-for-bit", flush=True)


if __name__ == "__main__":
    main()
