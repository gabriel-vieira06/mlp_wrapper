# Vivado topology presets

Each preset retains 784 MNIST inputs, 10 linear class scores, 32-bit data and
weights, `P_INT=10`, and ReLU hidden activations. All five `mlp.v` adapters
default to `N_MULT=2`, so each dense layer multiplies two input/weight pairs
in parallel for one output neuron. The generated `64_32` project uses the
shared topology RTL and batch testbench. The original project at
`Vivado/updated_mlp_wrapper.xpr` uses `dense_wrapper.sv` and its original
testbench.

| Directory | Full topology | Dense layers | Output memory prefix |
| --- | --- | ---: | --- |
| `64_32` | 784 → 64 → 32 → 10 | 3 | `H3` |
| `500_500` | 784 → 500 → 500 → 10 | 3 | `H3` |
| `256_128` | 784 → 256 → 128 → 10 | 3 | `H3` |
| `256` | 784 → 256 → 10 | 2 | `H2` |
| `512_256_128` | 784 → 512 → 256 → 128 → 10 | 4 | `H4` |

Each directory contains a distinct `mlp.v` adapter and `create_project.tcl`.
Compile only the selected adapter: all variants intentionally retain the
module name `mlp` for the existing block-design module reference. Shared RTL
in `common/mlp_topology.sv` constructs the required number of actual layers;
the single-hidden-layer version has no unused second hidden layer, and the
three-hidden-layer version adds a fourth dense stage for the output.

The shared accelerator blocks new input frames while inference/output is in
progress and holds each output beat stable under backpressure. The two-lane
configuration stores each input frame in a register array so the first dense
layer can select two pixels in parallel. Each layer reads adjacent weights
from a synchronous ROM with a block-ROM inference hint. Bias reads remain
combinational. The `N_MULT=1` configuration uses synchronous input BRAM for
the first layer.

The supplied weight and bias memories for the four alternative sizes from
`topologies_mem.zip` are included under their respective `mem/` directories.
The archive's `mems/` directories were mapped to the `mem/` paths used by the
project scripts.
File lengths and SHA-256 hashes are recorded in `memory_manifest.json`.

## Trained memory files

The `64_32` script stages its six trained memory files directly from
`Vivado/updated_mlp_wrapper.srcs/sources_1/new/`. The other presets use
`Vivado/topologies/<preset>/mem`. To use a different trained model for the same
topology, pass a memory directory containing the matching shapes below.

Every nonempty line must contain exactly eight hexadecimal digits, representing
one 32-bit two's-complement word. The current weight/input format has 22
fractional bits. The existing dense core's bias alignment is retained. For
weights, flatten a matrix shaped `(out_features, in_features)` in row-major
order: all weights of neuron 0, then all weights of neuron 1, and so on. Biases
follow output-neuron order. Do not include `0x` prefixes, address directives or
comments in these trained memory files.

| Preset | File | Required words |
| --- | --- | ---: |
| `64_32` | `H1W.mem` / `H1B.mem` | 50,176 / 64 |
| | `H2W.mem` / `H2B.mem` | 2,048 / 32 |
| | `H3W.mem` / `H3B.mem` | 320 / 10 |
| `500_500` | `H1W.mem` / `H1B.mem` | 392,000 / 500 |
| | `H2W.mem` / `H2B.mem` | 250,000 / 500 |
| | `H3W.mem` / `H3B.mem` | 5,000 / 10 |
| `256_128` | `H1W.mem` / `H1B.mem` | 200,704 / 256 |
| | `H2W.mem` / `H2B.mem` | 32,768 / 128 |
| | `H3W.mem` / `H3B.mem` | 1,280 / 10 |
| `256` | `H1W.mem` / `H1B.mem` | 200,704 / 256 |
| | `H2W.mem` / `H2B.mem` | 2,560 / 10 |
| `512_256_128` | `H1W.mem` / `H1B.mem` | 401,408 / 512 |
| | `H2W.mem` / `H2B.mem` | 131,072 / 256 |
| | `H3W.mem` / `H3B.mem` | 32,768 / 128 |
| | `H4W.mem` / `H4B.mem` | 1,280 / 10 |

Names follow the actual dense-layer sequence. In particular, `H2` is the
output layer for `256`, while `H4` is the output layer for `512_256_128`.

## Create and open a project

Use Vivado **2022.2**. From the repository root, for example:

```sh
vivado -mode batch -source Vivado/topologies/64_32/create_project.tcl
```

To override the output directory or the bundled trained memories:

```sh
vivado -mode batch -source Vivado/topologies/64_32/create_project.tcl \
    -tclargs /path/outside/repository/mlp_64_32 /path/to/mem/64_32
```

Substitute any supported preset directory in that command. Both arguments are
optional. By default `64_32` creates
`../mlp_64_32_vivado/mlp_64_32.xpr` relative to the repository root. Each preset
uses the same sibling-directory convention and its trained memories described
above.

Memory existence, lengths and hexadecimal formatting are checked **before**
creating the project. The bundled memories pass these checks. The script
refuses nonempty output directories and outputs inside the checkout.
To regenerate with different weights, use a
fresh output directory; previously staged project memories are independent
copies and do not update when the source memory directory changes.

After successful creation, open `<output>/mlp_<preset>.xpr`. The script:

1. Adds the selected `mlp.v`, the common topology RTL and the existing dense
   primitives, excluding the original `mlp.v` and `dense_wrapper.sv`.
2. Stages only that topology's weight/bias memories in the generated project.
3. Recreates the complete original processing system, DDR configuration,
   AXI DMA and module-reference block design from `PYNQ/mlp.tcl`.
4. Restores the current project's **50 MHz** accelerator clock; the older
   PYNQ Tcl export itself contains a 25 MHz setting.
5. Generates `mlp_design_wrapper` as the synthesis top, and configures
   `mlp_variant_tb` as the simulation top with all ten paired MNIST batches.

The scripts create a clean project rather than duplicating cached netlists,
checkpoints or bitstreams. They do not launch synthesis, implementation or
bitstream generation. Keep the checkout at the same location after project
creation, since RTL source paths reference it.

## Simulate a trained variant

Open the generated project and select **Run Behavioral Simulation**. The common
`mlp_variant_tb` sends **1,000 images from batch 00 by default**, checks output
counts and `TLAST`, and prints classification accuracy. `BATCH_ID` selects one
of the ten batches (0 through 9); `NUM_TESTS` selects 1 through 1,000 images
from the start of that batch. Images in the log retain their global indices
from 0 through 9,999. Output is written to `mnist_batch_XX_log.txt` in the
simulation working directory, where `XX` is the selected batch. No particular
accuracy is asserted for an unknown trained model.

Labels are parsed as text with explicit handling of `0x`/`0X` prefixes. This
avoids treating the prefix as unknown HDL bits in XSim. See
[label parsing and simulator compatibility](test_data/README.md#label-parsing-and-xsim-compatibility)
if an older generated project stops with an invalid-label error.

The testbench streams pixels and labels from the selected files as they are
needed. It keeps only the offered pixel and current label, instead of
preloading 784,000 pixels and 1,000 labels. The batch remains 1,000 images;
input-data storage in the testbench is constant rather than proportional to
the batch size. Input data and `TLAST` stay stable until each beat is accepted.

New projects also use a lightweight XSim evaluation profile: elaboration debug
is off, global signal logging is disabled, and a custom runtime runs the batch
without adding waveforms. It runs the actual RTL and trained weight memories.

The supplied 10,000-image data is stored as ten matching sample/label pairs in
`test_data/mnist_batches`. Every sample file contains 784,000 pixel words, and
its label file contains 1,000 labels. The project scripts import all pairs so
changing `BATCH_ID` does not require importing different data. See
[the batch data instructions](test_data/README.md) for the image ranges,
reproducible splitting command and migration of an existing project.

In Verilator, the two-lane `64_32` preset classified 967 of 1,000 images
from batch 00 correctly. All 10,000 raw scores matched the single-lane legacy
RTL on the same inputs and trained memories.

For simulation after generating the project (batch 03 covers images 3,000
through 3,999):

```tcl
open_project /path/outside/repository/mlp_64_32/mlp_64_32.xpr
set_property generic {BATCH_ID=3 NUM_TESTS=1000} [get_filesets sim_1]
launch_simulation
```

The lightweight runtime runs the selected batch automatically on launch.

Close any running simulation before changing these generics, then launch it
again to elaborate the selected batch. Previously generated projects also
need the new batch files added to `sim_1`; the migration commands are in the
batch data instructions.

### Reduce RAM use in an existing project

Update the checkout, close the running simulation, and open the generated
project. Apply the evaluation profile before launching a new simulation:

```tcl
source /path/to/mlp_wrapper/scripts/configure_lightweight_simulation.tcl
set_property generic {BATCH_ID=0 NUM_TESTS=1000} [get_filesets sim_1]
launch_simulation
```

The project must reference the updated `common/mlp_variant_tb.sv`; projects
using imported copies need that file refreshed. Close and relaunch simulation
so XSim re-elaborates with debug off; restarting an old snapshot is not enough.
Logs and the accuracy summary are still produced. See the
[simulation profile guide](../../scripts/README.md#lightweight-xsim-evaluation)
for waveform/debug tradeoffs and how to restore interactive debugging.

The legacy `64_32` testbench preloads 1,000 images. The generated `64_32`
project streams them with `mlp_variant_tb`, like the other presets. The larger
topologies have approximately 4–12 times as many weights, whose RTL memories
still contribute to simulation RAM use. Streaming removes the testbench's
batch arrays, and disabling tracing reduces retained signal history.

## Resource limit on the PYNQ-Z1

The target `xc7z020clg400-1` has 140 BRAM36 tiles (5,160,960 raw bits).
Arbitrary resident 32-bit weight tables for the four larger models exceed
that capacity, even before biases, input storage and BRAM geometry overhead:

| Preset | Weight words only | Ideal minimum BRAM36 tiles for 32-bit weights |
| --- | ---: | ---: |
| `500_500` | 647,000 | 562 |
| `256_128` | 234,752 | 204 |
| `256` | 203,264 | 177 |
| `512_256_128` | 566,528 | 492 |

These are storage bounds, not synthesis results. Constant-bit optimization can
depend on the actual trained values, but there is no guarantee of device fit.
A deployable design may need quantization, external DDR weight access or a
larger FPGA. Those architectural changes are outside these topology presets;
the presets retain 32-bit weights. Resource use and timing for the two-lane
configuration require Vivado synthesis and implementation results.

## Synthetic regression independent of trained memories

```sh
/workspace/mlp-env/bin/python tests/run_topology_tests.py
```

The test creates temporary, nonzero synthetic weight/bias files outside the
checkout and runs two different frames through each full-size preset's actual
`mlp.v` adapter. Every raw score is compared with an independent Python
fixed-point model. Tests cover layer counts, memory order, input gaps, repeated
frames, output counts/last flags, and output stalls in the `256` preset. These
tests verify wiring and arithmetic against known inputs.

The project Tcl entry points were also exercised with explicit Vivado command
stubs, including invalid/missing memories and the selected source/clock/top
configuration. Vivado itself is unavailable in the cloud environment, so
actual `.xpr` generation, vendor elaboration, synthesis, timing and board tests
remain to be run with Vivado. The trained memories are now included.
