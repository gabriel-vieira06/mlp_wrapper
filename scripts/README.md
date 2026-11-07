# Development scripts

Use **`topologies`** as the single branch for the topology variants, trained
memories and MNIST batches. Run the shell examples below from the repository
root. Tcl simulation commands run inside the Vivado Tcl console.

| Script | Purpose | Requirements |
| --- | --- | --- |
| [create_topology_project.tcl](create_topology_project.tcl) | Shared helper that creates a complete Zynq/DMA project for a selected topology | Vivado 2022.2 with Zynq-7000 device support |
| [configure_lightweight_simulation.tcl](configure_lightweight_simulation.tcl) | Apply a low-memory evaluation profile to the open topology project | Vivado 2022.2; simulation closed |
| [xsim_run_batch.tcl](xsim_run_batch.tcl) | Internal XSim runtime selected by the evaluation profile; runs the batch without adding waves | Called by XSim, not a standalone project generator |
| [split_mnist_mem.py](split_mnist_mem.py) | Split 10,000 MNIST images and labels into ten aligned batches | Python 3; standard library only |
| [synth_luts.tcl](synth_luts.tcl) | Synthesize the original `64_32` accelerator and report resources/timing | Vivado 2022.2 |

## Create a topology project

The creation helper is called by a topology-specific entry point. Choose
`500_500`, `256_128`, `256` (one hidden layer), or `512_256_128` (three hidden
layers). The variants all have 784 inputs and 10 output scores.

For example:

```sh
vivado -mode batch -source Vivado/topologies/256_128/create_project.tcl
```

This uses the bundled trained memories in
`Vivado/topologies/256_128/mem/` and creates
`../mlp_256_128_vivado/mlp_256_128.xpr`. The default output directory is a
sibling of the checkout, regardless of where Vivado was started.

The entry point accepts two optional positional arguments:

```text
create_project.tcl [OUTPUT_DIRECTORY] [MEMORY_DIRECTORY]
```

To choose another output directory while keeping the bundled weights:

```sh
vivado -mode batch -source Vivado/topologies/256_128/create_project.tcl \
    -tclargs ../my_mlp_256_128
```

To supply another set of trained weights as well:

```sh
vivado -mode batch -source Vivado/topologies/256_128/create_project.tcl \
    -tclargs ../my_mlp_256_128 /path/to/256_128/mem
```

The output directory must be outside the checkout and either absent or empty.
Close any project already open in the Vivado session before running the entry
point. Use Vivado **2022.2**, matching the block-design export.

The helper validates the trained memory names, word counts and eight-digit
hexadecimal format, and requires all ten MNIST sample/label pairs. It adds
only the selected `mlp.v` adapter, reconstructs the processing system and AXI
DMA from `PYNQ/mlp.tcl`, and configures a 50 MHz accelerator clock. The
synthesis top is `mlp_design_wrapper`; the simulation top is `mlp_variant_tb`.
No synthesis, implementation or bitstream run is launched.
New projects automatically receive the lightweight XSim evaluation profile
described below.

Trained memories are copied into the output directory. Editing the source
memories later does not change those staged copies. RTL paths reference the
checkout, so keep the checkout in place while using the generated project.
Run the topology-specific entry point rather than sourcing
`scripts/create_topology_project.tcl` directly: the helper alone only defines
procedures and does not select or create a project.

See [the topology guide](../Vivado/topologies/README.md) for the memory names,
layer sizes and PYNQ-Z1 resource constraints. Creating a project does not
establish that its trained model fits the FPGA.

### Run a selected MNIST batch

Open the generated project, select `BATCH_ID` from 0 through 9, and choose
`NUM_TESTS` from 1 through 1,000. Defaults are batch 00 and 1,000 images.

```tcl
open_project /path/to/mlp_256_128_vivado/mlp_256_128.xpr
set_property generic {BATCH_ID=3 NUM_TESTS=1000} [get_filesets sim_1]
launch_simulation
```

Batch 03 contains images 3,000 through 3,999. Results go to
`mnist_batch_03_log.txt` in the simulation working directory. Close an active
simulation before changing generics, then launch it again to elaborate the
new values. For a shorter smoke test, use `NUM_TESTS=2`.
The configured lightweight runtime runs the selected batch automatically on
launch, so a separate `run all` command is unnecessary.

Projects created before batch support need the new batch files added to
`sim_1`. Follow [the existing-project migration instructions](../Vivado/topologies/test_data/README.md#update-an-existing-topology-project).

### Lightweight XSim evaluation

The shared testbench reads one pixel at a time and one label per image. It
does not allocate arrays for the entire 1,000-image batch. This preserves the
batch-selection interface, RTL model and classification logs.

For an existing generated project, close simulation, open the project and run:

```tcl
source /path/to/mlp_wrapper/scripts/configure_lightweight_simulation.tcl
set_property generic {BATCH_ID=0 NUM_TESTS=1000} [get_filesets sim_1]
launch_simulation
```

The helper sets `xsim.elaborate.debug_level` to `off`, disables
`xsim.simulate.log_all_signals`, and selects `xsim_run_batch.tcl` as the custom
runtime. That runtime only executes `run all`; it does not add waveforms or
recursively log internal signals. These settings apply to the simulation
fileset, not synthesis or implementation. Enabled `.wcfg` entries in `sim_1`
are disabled without deleting their files, and the optional saved `xsim.view`
setting is cleared. This prevents old wave configurations from restoring
large signal collections during evaluation.

Keep the checkout at its current path: the custom runtime references it.
Refresh imported copies of `mlp_variant_tb.sv` if your project does not
reference the checkout's shared file. Close and relaunch simulation to rebuild
the snapshot; `restart` alone does not change elaboration debug settings.

The evaluation profile intentionally trades interactive signal inspection for
lower tracing overhead. For a short debugging session, close simulation and
restore the normal runtime and debug access:

```tcl
set_property xsim.elaborate.debug_level typical [get_filesets sim_1]
set_property xsim.simulate.custom_tcl {} [get_filesets sim_1]
set_property generic {BATCH_ID=0 NUM_TESTS=2} [get_filesets sim_1]
launch_simulation
```

To restore a specific saved wave configuration as well, re-enable that file
before launching: `set_property IS_ENABLED true [get_files /path/to/waves.wcfg]`.

Add only the signals needed for debugging; avoid recursively logging weight
memories and all internal signals for a full batch. Reapply the helper to
return to 1,000-image evaluation (restore `NUM_TESTS=1000` as shown above).

The larger models still contain their full RTL weight memories, and the
original `64_32` testbench also preloads 1,000 images. These changes remove
batch-sized testbench buffers and unnecessary tracing; they do not promise
that a larger topology's total PC RAM use equals `64_32`. Peak XSim RAM could
not be measured here because Vivado/XSim is not installed.

The property names and waveform-file behavior match the
[official Xilinx 2022.2 XSim Tcl sources](https://github.com/Xilinx/XilinxTclStore/blob/234341d2f6aa01b7ed747fc3528f3b1c8c65cf24/tclapp/xilinx/xsim/register_options.tcl).

## Split MNIST memories into batches

The ready-to-use batches are already committed under
`Vivado/topologies/test_data/mnist_batches/`. Run the splitter only when
preparing a dataset from its complete source memories:

```sh
python3 scripts/split_mnist_mem.py \
    /path/to/test_samples_10k.mem \
    /path/to/test_labels_10k.mem \
    ../new_mnist_batches
```

All three positional arguments are required:

| Argument | Expected contents |
| --- | --- |
| Samples file | Exactly 7,840,000 records: 784 pixels for each of 10,000 images; eight hexadecimal digits per pixel |
| Labels file | Exactly 10,000 hexadecimal labels in the range 0–9; an optional `0x` prefix is accepted |
| Output directory | A new directory that does not exist, including as an empty directory |

The splitter preserves the original record bytes and image/label order. It
creates `test_samples_00.mem` through `test_samples_09.mem` and matching
`test_labels_00.mem` through `test_labels_09.mem`, plus `manifest.json` with
counts, image ranges and SHA-256 hashes. Every pair holds 1,000 complete
images: 784,000 pixel records and 1,000 labels.

Invalid, truncated or extra records cause an error. Outputs are staged and
published as a complete directory only after validation, so a failed split
does not leave partially published batches. Existing output directories are
never overwritten; use a fresh destination when regenerating data.

For CLI help:

```sh
python3 scripts/split_mnist_mem.py --help
```

See [the dataset guide](../Vivado/topologies/test_data/README.md) for all batch
ranges and instructions for adding a new batch set to a Vivado project.

## Report LUT usage for the original accelerator

`synth_luts.tcl` runs standalone synthesis for the original `64_32` accelerator
using top `mlp`, device `xc7z020clg400-1`, and a 20 ns clock period (50 MHz).

```sh
vivado -mode batch -nojournal -nolog -source scripts/synth_luts.tcl \
    -tclargs ../mlp-synth-after
```

Both positional arguments are optional:

```text
synth_luts.tcl [OUTPUT_DIRECTORY] [RTL_DIRECTORY]
```

By default the output is `../mlp-synth`, and the RTL comes from
`Vivado/updated_mlp_wrapper.srcs/sources_1/new/`. An alternate RTL directory
must contain the same complete source set, including `dense_wrapper.sv`,
`mlp.v`, the dense/activation/memory modules and all six `H1`–`H3` weight/bias
files. For example, after exporting a baseline revision to a separate folder:

```sh
vivado -mode batch -nojournal -nolog -source scripts/synth_luts.tcl \
    -tclargs ../mlp-synth-before /path/to/baseline/rtl
```

The output directory must be outside both the checkout and RTL directory.
Known files in that output directory can be replaced on rerun, including
staged memories, reports and the checkpoint. Use different output directories
for before/after comparisons and the same Vivado version for both runs.

Outputs include `utilization.rpt`, `utilization_hierarchical.rpt`,
`memory_primitives.rpt`, `timing_summary.rpt`, `clock.xdc` and
`mlp_synth.dcp`. These are synthesis estimates; the script does not run
placement, routing or bitstream generation.

This script is **not a synthesis entry point for the four alternative
topologies**: their adapters and shared wrapper use a different source layout.
For those, first create the complete project with its topology-specific
entry point, then run synthesis on that project in Vivado. See
[the resource optimization guide](../docs/resource_optimization.md) for the
original accelerator's before/after comparison.

## Checks available without Vivado

In the prepared cloud environment:

```sh
/workspace/mlp-env/bin/python tests/test_mnist_batches.py
```

This runs the splitter regression and, when Verilator is available, the
1,000-image batch-selection testbench check. The latter uses a test-only
accelerator model to verify transfers and indexing; it is not a trained-model
accuracy test. The pure Python splitter tests need no external dependencies:

```sh
python3 tests/test_mnist_batches.py MnistBatchTests
```

Vivado 2022.2 is required to create projects or produce the synthesis reports.
