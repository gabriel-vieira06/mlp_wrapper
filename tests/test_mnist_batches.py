#!/usr/bin/env python3
"""Exercise MNIST batch splitting without substituting any user dataset.

Run: python3 tests/test_mnist_batches.py

Small fixtures patch the image/pixel constants to verify the same streaming
algorithm, byte preservation, alignment, strict input validation and atomic
output behavior. They do not substitute for verification of the user's actual
uploaded files. An optional Verilator check uses an explicitly synthetic mock
accelerator to exercise the real testbench's 1,000-frame batch selection.
"""

from __future__ import annotations

import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock


SCRIPT = Path(__file__).resolve().parents[1] / "scripts/split_mnist_mem.py"
SPEC = importlib.util.spec_from_file_location("split_mnist_mem_under_test", SCRIPT)
if SPEC is None or SPEC.loader is None:
    raise RuntimeError(f"Cannot import batch splitter: {SCRIPT}")
SPLITTER = importlib.util.module_from_spec(SPEC)
sys.modules[SPEC.name] = SPLITTER
previous_bytecode_setting = sys.dont_write_bytecode
try:
    sys.dont_write_bytecode = True
    SPEC.loader.exec_module(SPLITTER)
finally:
    sys.dont_write_bytecode = previous_bytecode_setting
DEFAULTS = (SPLITTER.TOTAL_IMAGES, SPLITTER.IMAGES_PER_BATCH,
            SPLITTER.PIXELS_PER_IMAGE)


class MnistBatchTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mnist-batch-tests-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.samples = self.root / "samples.mem"
        self.labels = self.root / "labels.mem"
        self.output = self.root / "batches"
        constants = mock.patch.multiple(
            SPLITTER, TOTAL_IMAGES=6, IMAGES_PER_BATCH=2, PIXELS_PER_IMAGE=3,
        )
        constants.start()
        self.addCleanup(constants.stop)
        # The high word identifies an image; its low word identifies a pixel.
        # Mixed line endings and an unterminated final record detect accidental
        # normalization, extra delimiters and pixel/label boundary mistakes.
        self.sample_records = []
        for image in range(6):
            for pixel in range(3):
                index = image*3 + pixel
                value = (image << 16) | pixel
                text = (f"{value:08X}" if index % 2 else f"{value:08x}").encode()
                ending = b"\r\n" if index % 3 == 0 else b"\n"
                self.sample_records.append(text + (ending if index < 17 else b""))
        self.label_records = [b"0x7\r\n", b"0X2\n", b"1\r\n", b"9\n",
                              b"0x0\r\n", b"0x5"]
        self.write_inputs()

    def write_inputs(self, samples=None, labels=None):
        self.samples.write_bytes(b"".join(self.sample_records if samples is None else samples))
        self.labels.write_bytes(b"".join(self.label_records if labels is None else labels))

    def split(self):
        return SPLITTER.split_mnist_mem(self.samples, self.labels, self.output)

    def assert_rejected_without_outputs(self, exception=ValueError):
        children = set(self.root.iterdir())
        with self.assertRaises(exception):
            self.split()
        self.assertFalse(self.output.exists(), "Invalid inputs published a partial batch directory")
        self.assertEqual(children, set(self.root.iterdir()), "Temporary staging files leaked")

    def test_production_dimensions_are_10000_images_in_ten_1000_image_batches(self):
        self.assertEqual(DEFAULTS, (10000, 1000, 784))

    def test_exact_image_and_label_boundaries_and_byte_preservation(self):
        original_samples = self.samples.read_bytes()
        original_labels = self.labels.read_bytes()
        returned = self.split()
        persisted = json.loads((self.output / "manifest.json").read_text())
        self.assertEqual(returned, persisted)
        names = {"manifest.json"}
        sample_parts = []
        label_parts = []
        for batch_id in range(3):
            sample_name = f"test_samples_{batch_id:02d}.mem"
            label_name = f"test_labels_{batch_id:02d}.mem"
            names.update((sample_name, label_name))
            sample_part = (self.output / sample_name).read_bytes()
            label_part = (self.output / label_name).read_bytes()
            self.assertEqual(sample_part, b"".join(self.sample_records[batch_id*6:(batch_id+1)*6]))
            self.assertEqual(label_part, b"".join(self.label_records[batch_id*2:(batch_id+1)*2]))
            self.assertEqual(len(sample_part.splitlines()), 6)
            self.assertEqual(len(label_part.splitlines()), 2)
            # Images remain complete and ordered within the batch.
            for offset, record in enumerate(sample_part.splitlines()):
                self.assertEqual(int(record, 16) >> 16, batch_id*2 + offset//3)
            sample_parts.append(sample_part)
            label_parts.append(label_part)
        self.assertEqual(set(p.name for p in self.output.iterdir()), names)
        self.assertEqual(b"".join(sample_parts), original_samples)
        self.assertEqual(b"".join(label_parts), original_labels)
        self.assertEqual(self.samples.read_bytes(), original_samples)
        self.assertEqual(self.labels.read_bytes(), original_labels)

    def test_rejects_truncated_samples(self):
        self.write_inputs(samples=self.sample_records[:-1])
        self.assert_rejected_without_outputs()

    def test_manifest_hashes_record_counts_and_inclusive_image_ranges(self):
        manifest = self.split()
        self.assertEqual(manifest["images"], 6)
        self.assertEqual(manifest["images_per_batch"], 2)
        self.assertEqual(manifest["pixels_per_image"], 3)
        self.assertEqual(manifest["source_samples"], {
            "file": self.samples.name,
            "records": 18,
            "sha256": hashlib.sha256(self.samples.read_bytes()).hexdigest(),
        })
        self.assertEqual(manifest["source_labels"], {
            "file": self.labels.name,
            "records": 6,
            "sha256": hashlib.sha256(self.labels.read_bytes()).hexdigest(),
        })
        self.assertEqual(len(manifest["batches"]), 3)
        for batch_id, batch in enumerate(manifest["batches"]):
            self.assertEqual(batch["batch_id"], batch_id)
            self.assertEqual(batch["first_image"], batch_id*2)
            self.assertEqual(batch["last_image"], batch_id*2 + 1)
            self.assertEqual(batch["images"], 2)
            for kind, stem, records in (("samples", "test_samples", 6),
                                        ("labels", "test_labels", 2)):
                name = f"{stem}_{batch_id:02d}.mem"
                raw = (self.output / name).read_bytes()
                self.assertEqual(batch[kind], {
                    "file": name, "records": records, "bytes": len(raw),
                    "sha256": hashlib.sha256(raw).hexdigest(),
                })

    def test_rejects_extra_samples(self):
        self.write_inputs(samples=[*self.sample_records[:-1], self.sample_records[-1] + b"\n",
                                   b"00000000\n"])
        self.assert_rejected_without_outputs()

    def test_rejects_truncated_labels(self):
        self.write_inputs(labels=self.label_records[:-1])
        self.assert_rejected_without_outputs()

    def test_rejects_extra_labels(self):
        self.write_inputs(labels=[*self.label_records[:-1], self.label_records[-1] + b"\n",
                                  b"0x3\n"])
        self.assert_rejected_without_outputs()

    def test_rejects_invalid_sample_records_even_after_an_earlier_complete_batch(self):
        for case, invalid in enumerate((b"0000000\n", b"000000000\n", b"0x000000\n",
                        b"gggggggg\n", b"\n", b" 00000000\n", b"00000000 \n",
                        b"0000_000\n", b"\xff0000000\n")):
            with self.subTest(record=invalid):
                self.output = self.root / f"invalid_samples_{case}"
                records = self.sample_records.copy()
                records[10] = invalid
                self.write_inputs(samples=records)
                self.assert_rejected_without_outputs()

    def test_rejects_invalid_labels_without_publishing_any_batch(self):
        for case, invalid in enumerate((b"a\n", b"0xA\n", b"10\n", b"-1\n", b"+1\n",
                        b"0x\n", b"\n", b"nothex\n", b"\xff\n")):
            with self.subTest(record=invalid):
                self.output = self.root / f"invalid_labels_{case}"
                records = self.label_records.copy()
                records[-1] = invalid
                self.write_inputs(labels=records)
                self.assert_rejected_without_outputs()

    def test_refuses_nonempty_output_without_overwriting_existing_files(self):
        self.output.mkdir()
        sentinel = self.output / "test_samples_00.mem"
        sentinel.write_bytes(b"existing user data\r\n")
        nested = self.output / "keep"
        nested.mkdir()
        (nested / "note.txt").write_bytes(b"preserve this too")
        with self.assertRaises((FileExistsError, ValueError)):
            self.split()
        self.assertEqual(sentinel.read_bytes(), b"existing user data\r\n")
        self.assertEqual((nested / "note.txt").read_bytes(), b"preserve this too")
        self.assertEqual(set(p.name for p in self.output.iterdir()),
                         {"test_samples_00.mem", "keep"})

    def test_missing_samples_does_not_create_output(self):
        self.samples.unlink()
        self.assert_rejected_without_outputs((FileNotFoundError, ValueError))

    def test_refuses_existing_empty_output_directory(self):
        self.output.mkdir()
        with self.assertRaises(FileExistsError):
            self.split()
        self.assertTrue(self.output.is_dir())
        self.assertEqual(list(self.output.iterdir()), [])

    def test_missing_labels_does_not_create_output(self):
        self.labels.unlink()
        self.assert_rejected_without_outputs((FileNotFoundError, ValueError))


MOCK_MLP = r"""`timescale 1ns / 1ps
// Test-only protocol mock; no model weights or accuracy claim.
module mlp (
    input wire clk, rst_n,
    input wire [31:0] s_axis_tdata,
    input wire s_axis_tvalid,
    output wire s_axis_tready,
    input wire s_axis_tlast,
    output wire [31:0] m_axis_tdata,
    output wire m_axis_tvalid,
    input wire m_axis_tready,
    output wire m_axis_tlast,
    output wire dbg_valid_in, dbg_valid_out
);
    integer image = 0;
    integer pixel = 0;
    integer score = 0;
    integer predicted = 0;
    integer cycles = 0;
    integer stalled_cycles = 0;
    logic streaming = 0;
    logic ready_gate = 0;
    logic was_stalled = 0;
    logic [31:0] held_data;
    logic held_last;
    assign s_axis_tready = rst_n && !streaming && ready_gate;
    assign m_axis_tvalid = rst_n && streaming;
    assign m_axis_tlast = streaming && score == 9;
    assign m_axis_tdata = score == predicted ? 32'h01000000 : 32'h00000000;
    assign dbg_valid_in = s_axis_tvalid;
    assign dbg_valid_out = m_axis_tvalid;
    // Change ready after the driver's falling edge to make offered beats stall.
    // This verifies that the scalar input is retained until the handshake.
    always @(negedge clk) begin
        #1;
        ready_gate = cycles % 7 >= 2;
    end
    always @(posedge clk) begin
        if (!rst_n) begin
            image <= 0; pixel <= 0; score <= 0;
            predicted <= 0; streaming <= 0; cycles <= 0;
            stalled_cycles = 0; was_stalled = 0;
        end else begin
            cycles <= cycles+1;
            if (was_stalled && (!s_axis_tvalid || s_axis_tdata !== held_data ||
                                s_axis_tlast !== held_last))
                $fatal(1, "Input data/valid/TLAST changed during backpressure");
            was_stalled = s_axis_tvalid && !s_axis_tready;
            if (was_stalled) stalled_cycles++;
            held_data = s_axis_tdata;
            held_last = s_axis_tlast;
            if (s_axis_tvalid && s_axis_tready) begin
                if (s_axis_tdata !== (((image+9000) << 16) | pixel))
                    $fatal(1, "Wrong batch/image/pixel at image %0d pixel %0d", image, pixel);
                if (s_axis_tlast !== (pixel == 783))
                    $fatal(1, "Input TLAST is misaligned");
                if (pixel == 0 && image < 2)
                    $display("MOCK_INPUT_IMAGE %0d", image+9000);
                if (pixel == 783) begin
                    pixel <= 0;
                    predicted <= (image+9000) % 10;
                    image <= image+1;
                    score <= 0;
                    streaming <= 1;
                end else pixel <= pixel+1;
            end
            if (streaming && m_axis_tready) begin
                if (score == 9) begin
                    streaming <= 0;
                    if (image == 1) $display("MOCK_FIRST_IMAGE_COMPLETE");
                    if (image == 1000) $display("MOCK_INPUT_STALLS %0d", stalled_cycles);
                end else score <= score+1;
            end
        end
    end
endmodule
"""


@unittest.skipUnless(importlib.util.find_spec("verilator") or shutil.which("verilator"),
                     "Optional batch testbench checks require Verilator")
class BatchTestbenchTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.build_temporary = tempfile.TemporaryDirectory(prefix="mnist-batch-tb-build-")
        cls.addClassCleanup(cls.build_temporary.cleanup)
        root = Path(cls.build_temporary.name)
        mock_rtl = root / "mlp_mock.sv"
        mock_rtl.write_text(MOCK_MLP)
        command = ([sys.executable, "-m", "verilator"]
                   if importlib.util.find_spec("verilator") else [shutil.which("verilator")])
        command += ["--binary", "--timing", "-Wno-fatal", "-j", "2",
                    "--top-module", "mlp_variant_tb", "-GBATCH_ID=9",
                    "--Mdir", str(root / "obj"), str(mock_rtl),
                    str(SCRIPT.parents[1] / "Vivado/topologies/common/mlp_variant_tb.sv")]
        # Deliberately keep NUM_TESTS at the production default of 1,000.
        build = subprocess.run(command, cwd=root, capture_output=True, text=True, timeout=120)
        if build.returncode:
            raise AssertionError((build.stdout + build.stderr)[-5000:])
        cls.executable = root / "obj/Vmlp_variant_tb"

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory(prefix="mnist-batch-tb-run-")
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.samples = self.root / "test_samples_09.mem"
        self.labels = self.root / "test_labels_09.mem"

    def write_samples(self, frames=1, tail_pixels=0, invalid_record=None):
        with self.samples.open("wb") as stream:
            for record in range(frames*784 + tail_pixels):
                image, pixel = divmod(record, 784)
                if record == invalid_record:
                    stream.write(b"nothex\n")
                else:
                    stream.write(f"{((image+9000) << 16) | pixel:08x}\n".encode())

    def write_labels(self, words=None):
        if words is None:
            words = [f"0x{image % 10:x}" for image in range(9000, 10000)]
        self.labels.write_text("".join(word + "\n" for word in words))

    def run_tb(self):
        return subprocess.run([str(self.executable)], cwd=self.root,
                              capture_output=True, text=True, timeout=30)

    def assert_failed_for(self, fragment):
        result = self.run_tb()
        text = result.stdout + result.stderr
        self.assertNotEqual(result.returncode, 0, text[-3000:])
        self.assertIn(fragment.lower(), text.lower())
        self.assertNotIn("completed 1000 images", text)
        return text

    def test_batch_09_default_1000_frames_and_global_image_indices(self):
        # Only batch09 exists. Every pixel encodes its global image/pixel index
        # and is checked by the mock, including beats held under backpressure.
        self.write_samples(frames=1000)
        self.write_labels()
        result = self.run_tb()
        self.assertEqual(result.returncode, 0, (result.stdout + result.stderr)[-5000:])
        self.assertIn("Batch 9 completed 1000 images, 1000 correct", result.stdout)
        self.assertRegex(result.stdout, r"MOCK_INPUT_STALLS [1-9][0-9]*")
        log = (self.root / "mnist_batch_09_log.txt").read_text().splitlines()
        self.assertEqual(len(log), 1000)
        for index, row in enumerate(log, 9000):
            expected = index % 10
            self.assertEqual(row, f"Image {index}: predicted={expected} expected={expected}")
        self.assertFalse((self.root / "mnist_batch_00_log.txt").exists())

    def test_invalid_full_width_label_is_rejected_before_any_pixel_is_sent(self):
        self.write_samples()
        for word in ("0x17", "0xffffffff", "0xa", "nothex"):
            with self.subTest(label=word):
                self.write_labels([word])
                text = self.assert_failed_for("label")
                self.assertNotIn("MOCK_INPUT_IMAGE", text)

    def test_future_invalid_label_is_read_only_after_first_inference_finishes(self):
        self.write_samples(frames=2)
        self.write_labels(["0x0", "0x17"])
        text = self.assert_failed_for("label")
        self.assertIn("MOCK_FIRST_IMAGE_COMPLETE", text)
        self.assertNotIn("MOCK_INPUT_IMAGE 9001", text)

    def test_truncated_future_label_is_read_only_after_first_inference_finishes(self):
        self.write_samples(frames=2)
        self.write_labels(["0x0"])
        text = self.assert_failed_for("label")
        self.assertIn("MOCK_FIRST_IMAGE_COMPLETE", text)
        self.assertNotIn("MOCK_INPUT_IMAGE 9001", text)

    def test_invalid_future_pixel_does_not_prevent_first_inference(self):
        self.write_samples(frames=2, invalid_record=784 + 11)
        self.write_labels(["0x0", "0x1"])
        text = self.assert_failed_for("pixel")
        self.assertIn("MOCK_FIRST_IMAGE_COMPLETE", text)
        self.assertIn("MOCK_INPUT_IMAGE 9001", text)

    def test_truncated_future_pixels_do_not_prevent_first_inference(self):
        self.write_samples(frames=1, tail_pixels=57)
        self.write_labels(["0x0", "0x1"])
        text = self.assert_failed_for("pixel")
        self.assertIn("MOCK_FIRST_IMAGE_COMPLETE", text)
        self.assertIn("MOCK_INPUT_IMAGE 9001", text)

    def test_invalid_first_pixel_is_rejected_before_transmitting_a_frame(self):
        self.write_samples(invalid_record=0)
        self.write_labels(["0x0"])
        text = self.assert_failed_for("pixel")
        self.assertNotIn("MOCK_INPUT_IMAGE", text)

    def test_missing_input_files_fail_before_inference(self):
        for missing in ("samples", "labels"):
            with self.subTest(missing=missing):
                self.write_samples()
                self.write_labels(["0x0"])
                getattr(self, missing).unlink()
                text = self.assert_failed_for("cannot open")
                self.assertNotIn("MOCK_INPUT_IMAGE", text)


if __name__ == "__main__":
    unittest.main(verbosity=2)
