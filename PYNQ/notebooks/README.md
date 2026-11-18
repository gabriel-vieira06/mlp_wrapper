# PYNQ-Z1 topology validation

Open one notebook at a time in Jupyter on a PYNQ-Z1 running PYNQ 2.7 or
newer. Keep `pynq_validation.py` alongside the notebooks. The board's Python
kernel needs PYNQ, NumPy and IPython. Each run reprograms the FPGA, then
classifies 10,000 labeled MNIST images.

| Notebook | Network | Default bitstream relative to `topologies/` |
| --- | --- | --- |
| [64-32](validation_64-32.ipynb) | 784 → 64 → 32 → 10 | `64-32/mlp_64_32.bit` |
| [256](validation_256.ipynb) | 784 → 256 → 10 | `256/mlp_256.bit` |
| [256-128](validation_256-128.ipynb) | 784 → 256 → 128 → 10 | `256-128/mlp_256_128.bit` |
| [500-500](validation_500-500.ipynb) | 784 → 500 → 500 → 10 | `500-500/mlp_500_500.bit` |
| [512-256-128](validation_512-256-128.ipynb) | 784 → 512 → 256 → 128 → 10 | `512-256-128/mlp_512_256_128.bit` |

## Run on the board

1. Copy this directory to the board's Jupyter workspace or open it from the
   board checkout. Leave the helper and notebooks in the same directory.
2. Keep each implemented `.bit` and its matching `.hwh` together with the
   same filename stem. PYNQ uses the `.hwh` to discover the AXI DMA interface.
   Keep the matching `.tcl` as part of the Vivado export for reference. Set
   `TOPOLOGIES_DIR` if the topology folders are outside
   `/home/xilinx/vivado_projects/topologies`. Set `BITSTREAM` to the exact
   `.bit` path if the export uses a different stem or folder layout.
3. Keep `test_samples_00.mem` through `test_samples_09.mem` and the matching
   `test_labels_00.mem` through `test_labels_09.mem` in
   `/home/xilinx/vivado_projects/test_files`. Set `TEST_DIR` to a different
   directory as needed. The [repository batches](../../Vivado/topologies/test_data/mnist_batches)
   can also be used on a board with the checkout.
4. Open the notebook for the selected topology and run all cells. Leave the
   FPGA free of other applications while it runs. After a DMA timeout or
   transfer error, rerun the notebook from the top to reload the overlay.
   Reboot the board before retrying if the DMA reset failed.

Each sample file holds 1,000 images with 784 fixed-point words per image.
One DMA transaction sends an image and receives ten signed class scores.
The index of the highest score is compared with its paired hexadecimal label.

## Interpret the results

- **Per batch** shows correct and total classifications, accuracy, elapsed
  classification time and throughput in images per second.
- **DMA latency** reports mean, median and 95th-percentile round-trip time
  per image, including DMA software overhead and FPGA execution.
- **Overall accuracy** uses all 10,000 predictions. The confusion matrix uses
  true digits as rows and predicted digits as columns. Per-class accuracy is
  the fraction correct among examples of each true class.

Batch timing includes preparing inference buffers, DMA transfers and selecting
predictions. File parsing, overlay programming and warm-up are outside that
measurement. Compare runs using the same board and test files. The notebook
keeps the results dictionary in `report` for further analysis.
