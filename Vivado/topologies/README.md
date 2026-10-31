# Alternative Vivado topologies

Each preset retains 784 MNIST inputs, 10 linear class scores, 32-bit data and
weights, `P_INT=10`, and ReLU hidden activations. The original `64_32` project
and its trained memory files remain separate.

| Directory | Full topology | Dense layers | Output memory prefix |
| --- | --- | ---: | --- |
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
progress and holds each output beat stable under backpressure. It reuses the
existing `dense.sv` arithmetic, synchronous weight ROMs and single-lane input
BRAM. The supplied weight and bias memories from `topologies_mem.zip` are
included, unchanged, under each preset's `mem/` directory. The archive's
`mems/` directories were mapped to the `mem/` paths used by the project scripts.
File lengths and SHA-256 hashes are recorded in `memory_manifest.json`.

## Trained memory files

The default project scripts already select `Vivado/topologies/<preset>/mem`.
All 24 supplied files have been checked for the expected lengths and hexadecimal
format. To use a different trained model, pass a separate memory directory such
as `/path/to/mem/256_128`. Do not reuse the `64_32` memories: their lengths and
tensor shapes are different.

Every nonempty line must contain exactly eight hexadecimal digits, representing
one 32-bit two's-complement word. The current weight/input format has 22
fractional bits. The existing dense core's bias alignment is retained. For
weights, flatten a matrix shaped `(out_features, in_features)` in row-major
order: all weights of neuron 0, then all weights of neuron 1, and so on. Biases
follow output-neuron order. Do not include `0x` prefixes, address directives or
comments in these trained memory files.

| Preset | File | Required words |
| --- | --- | ---: |
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
vivado -mode batch -source Vivado/topologies/256_128/create_project.tcl
```

To override the output directory or the bundled trained memories:

```sh
vivado -mode batch -source Vivado/topologies/256_128/create_project.tcl \
    -tclargs /path/outside/repository/mlp_256_128 /path/to/mem/256_128
```

Use any of the four preset directory names in that command. Both arguments
are optional: the default output directory is a sibling of the repository
named `mlp_<preset>_vivado`, and the default memory directory is
`Vivado/topologies/<preset>/mem`.

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
   `mlp_variant_tb` as the simulation top with the shared MNIST test data.

The scripts create a clean project rather than duplicating cached netlists,
checkpoints or bitstreams. They do not launch synthesis, implementation or
bitstream generation. Keep the checkout at the same location after project
creation, since RTL source paths reference it.

## Simulate a trained variant

Open the generated project and select **Run Behavioral Simulation**. The common
`mlp_variant_tb` sends 10 images by default, checks output counts and `TLAST`,
prints classification accuracy and writes `mnist_log.txt` in the simulation
working directory. Set its `NUM_TESTS` parameter to change the sample count,
up to the 10,000 images present in the shared fixture. No particular accuracy
is asserted for an unknown trained model.

The bundled memories were exercised with Verilator using this testbench and
10 MNIST images per preset. All four simulations completed without memory-load
errors. Observed correct classifications were 10/10 (`500_500`), 10/10
(`256_128`), 9/10 (`256`), and 10/10 (`512_256_128`). This is a small integration
smoke test, not an evaluation of full test-set accuracy or a Vivado/XSim run.

For batch simulation after generating the project:

```tcl
open_project /path/outside/repository/mlp_256_128/mlp_256_128.xpr
launch_simulation
run all
```

## Resource limit on the PYNQ-Z1

The target `xc7z020clg400-1` has 140 BRAM36 tiles (5,160,960 raw bits).
Arbitrary resident 32-bit weight tables for all four requested models exceed
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
32-bit precision has not been silently reduced. No new bitstreams or hardware
validation are claimed.

## Synthetic regression independent of trained memories

```sh
/workspace/mlp-env/bin/python tests/run_topology_tests.py
```

The test creates temporary, nonzero synthetic weight/bias files outside the
checkout and runs two different frames through each full-size preset's actual
`mlp.v` adapter. Every raw score is compared with an independent Python
fixed-point model. Tests cover layer counts, memory order, input gaps, repeated
frames, output counts/last flags, and output stalls in the `256` preset. All
80 scores matched. These tests establish wiring/arithmetic behavior, not
trained-model accuracy or FPGA resource fit.

The project Tcl entry points were also exercised with explicit Vivado command
stubs, including invalid/missing memories and the selected source/clock/top
configuration. Vivado itself is unavailable in the cloud environment, so
actual `.xpr` generation, vendor elaboration, synthesis, timing and board tests
remain to be run with Vivado. The trained memories are now included.
