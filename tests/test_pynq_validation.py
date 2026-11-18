#!/usr/bin/env python3
"""Exercise the board validation workflow with a fake PYNQ DMA and small batches."""

import importlib.util
from pathlib import Path
import sys
import tempfile
import types
import unittest
from unittest import mock

import numpy as np


HELPER = Path(__file__).resolve().parents[1] / "PYNQ/notebooks/pynq_validation.py"
SPEC = importlib.util.spec_from_file_location("pynq_validation", HELPER)
VALIDATION = importlib.util.module_from_spec(SPEC)
with mock.patch.object(sys, "dont_write_bytecode", True):
    SPEC.loader.exec_module(VALIDATION)


class Buffer(np.ndarray):
    def freebuffer(self):
        self.board.events.append("free")


class Channel:
    def __init__(self, board, name, transferred):
        self.board = board
        self.name = name
        self.transferred = transferred
        self.error = False
        self.idle = True
        self.running = True

    def transfer(self, buffer):
        self.board.transfer(self.name, buffer)

    def wait(self):
        if not self.idle:
            raise AssertionError("Called an unbounded DMA wait before the channel was idle")
        self.board.events.append(f"{self.name}.wait")
        if self.name == "recv":
            self.board.receive_buffer.view(np.int32)[:] = self.board.device_output
            self.board.receive_buffer = None


class FakeBoard:
    def __init__(self, inputs, predictions):
        self.inputs = inputs
        self.predictions = predictions
        self.next_input = 0
        self.bitstream = None
        self.programmed = False
        self.events = []
        self.stall = False
        self.reset_stalls = False
        self.receive_buffer = None
        self.device_output = np.empty(10, dtype=np.int32)
        self.scatter_gather = "0"
        self.sendchannel = Channel(self, "send", 784 * 4)
        self.recvchannel = Channel(self, "recv", 10 * 4)
        self.mmio = mock.Mock()
        self.mmio.read.side_effect = self.read_register
        self.mmio.write.side_effect = self.write_register

    def overlay(self, bitstream, download=True):
        if download:
            raise AssertionError("Programming must wait for metadata validation")
        self.bitstream = Path(bitstream)
        metadata = {
            "type": "xilinx.com:ip:axi_dma:7.1",
            "parameters": {
                "c_include_sg": self.scatter_gather,
                "c_include_mm2s": "1",
                "c_include_s2mm": "1",
                "c_sg_length_width": "14",
                "c_m_axis_mm2s_tdata_width": "32",
                "c_s_axis_s2mm_tdata_width": "32",
            },
        }
        return types.SimpleNamespace(
            ip_dict={"axi_dma_0": metadata}, axi_dma_0=self, download=self.download
        )

    def download(self):
        self.events.append("download")
        self.programmed = True

    def allocate(self, shape, dtype):
        if not self.programmed:
            raise AssertionError("Allocated before programming")
        buffer = np.empty(shape, dtype=dtype).view(Buffer)
        buffer.board = self
        return buffer

    def transfer(self, name, buffer):
        self.events.append(f"{name}.transfer")
        if name == "recv":
            if self.receive_buffer is not None:
                raise AssertionError("Receive submitted while the previous receive was pending")
            self.receive_buffer = buffer
            self.recvchannel.idle = False
            return
        if self.receive_buffer is None:
            raise AssertionError("Send submitted before receive was armed")
        self.sendchannel.idle = False
        if self.stall:
            return
        index = max(self.next_input - 1, 0)  # The first frame is used for warm-up.
        np.testing.assert_array_equal(buffer.view(np.uint32), self.inputs[index])
        output = self.device_output
        # Use positive and negative signed maxima. In the positive case an
        # unsigned argmax would choose one of the negative scores.
        output[:] = -5
        output[self.predictions[index]] = 3 if index % 2 == 0 else -1
        self.next_input += 1
        self.sendchannel.idle = self.recvchannel.idle = True

    def write_register(self, offset, value):
        if offset != 0 or value != 4:
            raise AssertionError("Expected AXI DMA soft reset")
        self.events.append("reset")

    def read_register(self, offset):
        return {0x00: 4 if self.reset_stalls else 0, 0x04: 1, 0x34: 1}[offset]


class BoardValidationTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="pynq-validation-tests-")
        self.addCleanup(temp.cleanup)
        self.root = Path(temp.name)
        self.topologies_dir = self.root / "topologies"
        self.test_dir = self.root / "test_files"
        self.test_dir.mkdir()
        self.bitstream = self.topologies_dir / "256-128" / "mlp_256_128.bit"
        self.bitstream.parent.mkdir(parents=True)
        for suffix in (".bit", ".hwh", ".tcl"):
            self.bitstream.with_suffix(suffix).touch()
        # Include high bits to ensure that test words reach DMA as raw bits.
        inputs = np.arange(4 * 784, dtype=np.uint32).reshape(4, 784) | 0xF0000000
        self.board = FakeBoard(inputs, [7, 2, 0, 9])
        labels = ["0x7\r\n0X2", "1\n9\n"]
        for batch in range(2):
            words = inputs[batch * 2 : batch * 2 + 2].ravel()
            (self.test_dir / f"test_samples_{batch:02d}.mem").write_text(
                "\n".join(f"{word:08X}" for word in words), encoding="ascii"
            )
            (self.test_dir / f"test_labels_{batch:02d}.mem").write_bytes(
                labels[batch].encode("ascii")
            )
        constants = mock.patch.multiple(VALIDATION, BATCH_COUNT=2, IMAGES_PER_BATCH=2)
        constants.start()
        self.addCleanup(constants.stop)
        pynq = types.ModuleType("pynq")
        pynq.Overlay = self.board.overlay
        pynq.allocate = self.board.allocate
        modules = mock.patch.dict(sys.modules, {"pynq": pynq})
        modules.start()
        self.addCleanup(modules.stop)

    def validate(self, **kwargs):
        return VALIDATION.validate_on_board(
            "256-128", self.topologies_dir, self.test_dir, **kwargs
        )

    def test_all_frames_and_signed_predictions(self):
        report = self.validate()
        self.assertEqual(self.board.bitstream, self.bitstream)
        self.assertEqual(self.board.next_input, 5)
        transfers = [event for event in self.board.events if event.endswith(".transfer")]
        self.assertEqual(transfers, ["recv.transfer", "send.transfer"] * 5)
        self.assertEqual(self.board.events.count("recv.wait"), 5)
        self.assertEqual(self.board.events.count("send.wait"), 5)
        self.assertEqual(self.board.events.count("free"), 2)
        self.assertEqual([batch["batch"] for batch in report["batches"]], [0, 1])
        self.assertEqual([batch["correct"] for batch in report["batches"]], [2, 1])
        overall = report["overall"]
        self.assertEqual(overall["images"], 4)
        self.assertEqual(overall["correct"], 3)
        self.assertEqual(overall["accuracy_pct"], 75)
        for key in ("classification_s", "images_per_s", "dma_mean_ms",
                    "dma_median_ms", "dma_p95_ms"):
            self.assertGreater(overall[key], 0)
        expected = np.zeros((10, 10), dtype=int)
        expected[7, 7] = expected[2, 2] = expected[1, 0] = expected[9, 9] = 1
        np.testing.assert_array_equal(report["confusion_matrix"], expected)

    def test_explicit_bitstream_uses_matching_metadata(self):
        bitstream = self.bitstream.with_name("custom.bit")
        self.bitstream.rename(bitstream)
        self.bitstream.with_suffix(".hwh").rename(bitstream.with_suffix(".hwh"))
        report = self.validate(bitstream=bitstream)
        self.assertEqual(self.board.bitstream, bitstream)
        self.assertEqual(report["hwh"], str(bitstream.with_suffix(".hwh")))
        self.assertIsNone(report["tcl"])

    def test_missing_hwh_rejected_before_programming(self):
        self.bitstream.with_suffix(".hwh").unlink()
        with self.assertRaises(FileNotFoundError):
            self.validate()
        self.assertFalse(self.board.programmed)

    def test_missing_later_batch_rejected_before_programming(self):
        (self.test_dir / "test_labels_01.mem").unlink()
        with self.assertRaises(FileNotFoundError):
            self.validate()
        self.assertFalse(self.board.programmed)

    def test_scatter_gather_overlay_rejected_before_programming(self):
        self.board.scatter_gather = "1"
        with self.assertRaises((ValueError, RuntimeError)):
            self.validate()
        self.assertFalse(self.board.programmed)

    def test_malformed_and_wrong_length_data_never_reaches_dma(self):
        sample_file = self.test_dir / "test_samples_00.mem"
        label_file = self.test_dir / "test_labels_00.mem"
        good_samples = sample_file.read_bytes()
        good_labels = label_file.read_bytes()
        for path, payload in (
            (sample_file, b"gggggggg" + good_samples[8:]),
            (sample_file, good_samples + b"\n00000000"),
            (sample_file, good_samples[:-9]),
            (label_file, b"0x100000007\n2"),
            (label_file, b"0x7"),
        ):
            with self.subTest(path=path.name, byte_count=len(payload)):
                sample_file.write_bytes(good_samples)
                label_file.write_bytes(good_labels)
                path.write_bytes(payload)
                with self.assertRaises(ValueError):
                    self.validate()
                self.assertNotIn("recv.transfer", self.board.events)

    def test_short_receive_rejected(self):
        self.board.recvchannel.transferred = 36
        with self.assertRaises(RuntimeError):
            self.validate()
        self.assertEqual(self.board.next_input, 1)
        self.assertEqual(self.board.events.count("free"), 2)

    def test_timeout_resets_before_releasing_active_dma_buffers(self):
        self.board.stall = True
        with self.assertRaises((TimeoutError, RuntimeError)):
            self.validate(timeout_s=0.01)
        self.assertEqual(self.board.events[-3:], ["reset", "free", "free"])

    def test_failed_dma_reset_retains_active_buffers(self):
        with mock.patch.object(VALIDATION, "_unreleased_buffers", []):
            self.board.stall = self.board.reset_stalls = True
            with self.assertRaises(RuntimeError):
                self.validate(timeout_s=0.01)
            self.assertIn("reset", self.board.events)
            self.assertNotIn("free", self.board.events)
            events = self.board.events[:]
            with self.assertRaises(RuntimeError):
                self.validate()
            self.assertEqual(self.board.events, events)


if __name__ == "__main__":
    unittest.main()
