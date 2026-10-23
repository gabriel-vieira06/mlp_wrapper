# Reducing LUT consumption

The checked-in Vivado synthesis report attributes 34,449 LUTs and 29,330
registers to the MLP, with **zero block RAM**. The full placed design uses
36,729 LUTs and 98.74% of slices. These are historical reports from the original
RTL, not measurements of the changes below.

The main problem is memory implementation: asynchronous weight ROM reads turn
the weight tables into LUT logic. The first-layer input array also uses
784 × 32 = 25,088 flip-flops and a large read mux.

## RTL changes

- `mem_behavioral_W.sv` now has a clocked read and requests block ROM.
- `dense.sv` waits one cycle for each memory read before capturing operands.
  The wait applies after input/neuron address changes, including the first
  access and the transition between neurons.
- With the default `N_MULT=1`, `dense_wrapper.sv` stores input pixels in a
  synchronous simple dual-port block RAM and passes the selected word to the
  first layer. The array has no reset; every complete input frame overwrites
  all words before inference starts.
- `mult2c.sv` uses native signed multiplication instead of absolute-value
  conversion and conditional result negation. The full 64-bit product is
  preserved for the default 32-bit operands, including minimum negative values.

Weights, biases, activation functions, fixed-point precision and the wrapper's
external ports are unchanged. Small bias ROMs remain asynchronous. The internal
`dense` and weight-memory interfaces have changed; use the updated wrapper with
them. No generated Vivado netlist, checkpoint or bitstream has been replaced.

The memory wait adds one cycle per input chunk. For `N_MULT=1`, that is
50,176 + 2,048 + 320 = **52,544 extra cycles per image**, about 33% more latency
than the original. At the block design's 50 MHz clock this adds 1.05088 ms.
This trades more BRAM and latency for fewer LUTs and registers, without
quantizing the model.

For `N_MULT>1`, the original parallel input-buffer path remains. The synchronous
weight ROM can require multiple read ports or replicated BRAMs. Do not assume
the single-lane resource savings or device fit hold for every parallel setting.

## Measured results

Both versions were synthesized with the same open-source flow:
YoWASP Yosys `0.70.0.0.post1259`, the slang SystemVerilog frontend, top `mlp`,
and `synth_xilinx -family xc7`. Counts below come from the final mapped
netlists, with `N_MULT=1` and the same committed memory contents.

| Resource | Original RTL | Optimized RTL |
| --- | ---: | ---: |
| LUT primitives | 79,447 | 3,132 |
| Flip-flops | 29,234 | 4,174 |
| RAMB18E1 | 0 | 90 |
| RAMB36E1 | 0 | 3 |
| DSP48E1 | 13 | 13 |

This is a **96.06% reduction in mapped LUT primitives** and an 85.72% reduction
in flip-flops in this flow. The block memories occupy 48 RAMB36-equivalent
tiles out of the device's 140. All three weight memories and the input pixel
buffer map to block RAM; the input buffer uses one RAMB36E1.

These are **Yosys estimates, not new Vivado results**. In particular, Yosys's
original LUT count is substantially higher than the checked-in Vivado count;
the two tools optimize the original ROM/mux structure differently. Do not apply
the 96.06% reduction to the historical Vivado count. Vivado synthesis and full
implementation remain necessary to establish the actual device utilization
and timing.

Functional validation completed with:

- 1,000 MNIST frames: all 10,000 raw logits matched the original bit-for-bit;
  both versions classified 967/1,000 images correctly.
- Ten frames each with `N_MULT=2` and `N_MULT=3`: all raw logits matched,
  including partial input chunks in the three-lane configuration.
- 85,600 exhaustive, boundary and randomized multiplier cases passed.

## Functional regression

From the repository root, using Python with the `verilator` package installed:

```sh
/workspace/mlp-env/bin/python tests/run_rtl_tests.py
```

This checks 65,536 exhaustive 8-bit products, 20,064 boundary/random 32-bit
products, and ten complete MNIST inferences against committed raw output
values from the original RTL. Inference checks include input-valid gaps,
repeated frames, output counts, last flags, and a completion watchdog. Generated
files and logs go to a fresh directory outside the checkout. Output readiness
is held high; this does not verify arbitrary AXI output backpressure.

For a larger bit-for-bit comparison, export the original RTL without changing
the current checkout:

```sh
mkdir -p /workspace/mlp-before
git archive 082e4231fc3b992f18bbbe41aecf70ae052791bb \
    Vivado/updated_mlp_wrapper.srcs/sources_1/new | tar -x -C /workspace/mlp-before
/workspace/mlp-env/bin/python tests/run_rtl_tests.py --samples 1000 \
    --reference-rtl /workspace/mlp-before/Vivado/updated_mlp_wrapper.srcs/sources_1/new
```

Use `--n-mult 2 --samples 10` with the same reference argument to check the
parallel fallback. The test uses the same committed weights and input data for
both designs and compares all raw logits, independent of their different
completion times. The original RTL has existing width/lint warnings, so the
runner reports warnings without treating every one as a fatal build error.

The open-source resource measurement used the following command in separate
output directories containing copies of the six weight/bias `.mem` files:

```sh
XDG_CACHE_HOME=/workspace/mlp-cache /workspace/mlp-env/bin/yowasp-yosys \
    -l synthesis.log -p 'read_slang -j 1 --top mlp /path/to/rtl/*.sv /path/to/rtl/mlp.v; synth_xilinx -family xc7 -top mlp; stat -tech xilinx; write_json synthesized.json'
```

Set `/path/to/rtl` to each exported RTL directory. The optional tool is
available as `yowasp-yosys==0.70.0.0.post1259` from PyPI; it is not required
for simulation or Vivado. Sum the `LUT1` through `LUT6` cells in the final
`mlp` module to reproduce the mapped LUT count.

## Vivado resource comparison

With Vivado 2022.2 on `PATH`, run:

```sh
vivado -mode batch -nojournal -nolog -source scripts/synth_luts.tcl \
    -tclargs /workspace/mlp-synth-after
vivado -mode batch -nojournal -nolog -source scripts/synth_luts.tcl \
    -tclargs /workspace/mlp-synth-before \
    /workspace/mlp-before/Vivado/updated_mlp_wrapper.srcs/sources_1/new
```

The script synthesizes the standalone `mlp` top for `xc7z020clg400-1`, stages
the six memory files in the output directory, and writes utilization,
hierarchical utilization, memory primitive, timing and checkpoint outputs.
Compare both `utilization.rpt` files using the same tool version. Check for
`RAMB18E1`/`RAMB36E1` primitives in `memory_primitives.rpt`. The 20 ns clock
matches the block design. Synthesis timing is preliminary; full implementation
is required for final area and timing results.

The original block design uses a module reference to the tracked `mlp.v` and
SystemVerilog sources. In the existing Vivado project, refresh the module
reference/output products and reset the MLP out-of-context synthesis run
(`mlp_design_mlp_0_0_synth_1`), then rebuild synthesis and implementation. Reusing
the checked-in checkpoints or bitstreams will still use the original design.
