# MNIST test batches

`mnist_batches/` contains the supplied 10,000 test images split into **ten
sample/label pairs**. Each image occupies 784 consecutive 32-bit pixel words.
Every pair contains 1,000 complete images and their 1,000 matching labels.
The source order, hexadecimal values and record bytes are preserved.

| BATCH_ID | Sample file | Label file | Original image indices |
| ---: | --- | --- | --- |
| 0 | `test_samples_00.mem` | `test_labels_00.mem` | 0–999 |
| 1 | `test_samples_01.mem` | `test_labels_01.mem` | 1,000–1,999 |
| 2 | `test_samples_02.mem` | `test_labels_02.mem` | 2,000–2,999 |
| 3 | `test_samples_03.mem` | `test_labels_03.mem` | 3,000–3,999 |
| 4 | `test_samples_04.mem` | `test_labels_04.mem` | 4,000–4,999 |
| 5 | `test_samples_05.mem` | `test_labels_05.mem` | 5,000–5,999 |
| 6 | `test_samples_06.mem` | `test_labels_06.mem` | 6,000–6,999 |
| 7 | `test_samples_07.mem` | `test_labels_07.mem` | 7,000–7,999 |
| 8 | `test_samples_08.mem` | `test_labels_08.mem` | 8,000–8,999 |
| 9 | `test_samples_09.mem` | `test_labels_09.mem` | 9,000–9,999 |

Each sample file has **784,000 records** and each label file has **1,000
records**. `manifest.json` records the counts, image ranges, source hashes and
per-file SHA-256 hashes. Concatenating sample files in batch order exactly
reconstructs `test_samples_10k.mem`; the same is true for the labels.

## Select a batch in Vivado

New projects created by the topology scripts import all 20 `.mem` files and
default to `BATCH_ID=0 NUM_TESTS=1000`. With the project open and any running
simulation closed:

```tcl
set_property generic {BATCH_ID=9 NUM_TESTS=1000} [get_filesets sim_1]
launch_simulation
```

This evaluates images 9,000 through 9,999, prints the classification summary
and writes `mnist_batch_09_log.txt`. For a shorter smoke test, reduce
`NUM_TESTS`, for example to `2`; it must remain between 1 and 1,000. The same
batch-selection interface applies to all four topologies.

With the lightweight profile applied by new projects, launching simulation
runs the batch automatically. Pixels and labels are streamed from disk rather
than loading the complete batch into testbench arrays. The files and default
1,000-image batch size are unchanged.

## Update an existing topology project

Projects generated before batch support reference the old unpartitioned
fixtures. After updating the checkout, close any running simulation, open the
existing project, and add the new files using the real checkout path:

```tcl
set batch_dir [file normalize /path/to/mlp_wrapper/Vivado/topologies/test_data/mnist_batches]
add_files -fileset sim_1 -norecurse [glob -directory $batch_dir test_samples_*.mem test_labels_*.mem]
set_property generic {BATCH_ID=0 NUM_TESTS=1000} [get_filesets sim_1]
update_compile_order -fileset sim_1
source /path/to/mlp_wrapper/scripts/configure_lightweight_simulation.tcl
launch_simulation
```

The existing project must reference the updated shared
`common/mlp_variant_tb.sv`. The original `64_32` testbench and its legacy
fixtures are unchanged.

For a project that already has batch support, only refresh the shared testbench
if it was imported as a copy, apply the profile script above, and relaunch
simulation. Debug/waveform settings require re-elaboration of the snapshot.

## Label parsing and XSim compatibility

The supplied labels use tokens such as `0x7`. The streaming testbench reads
labels as text, handles an optional `0x` or `0X` prefix explicitly, validates
every hexadecimal character and accepts only classes 0 through 9. Plain `7`
and leading-zero forms are also accepted. Invalid tokens and oversized values
are rejected before pixels for that image are transmitted; they cannot be
silently truncated into a valid class.

A direct `$fscanf(..., "%h", word)` can interpret the `x` in `0x7` as an
unknown hexadecimal digit in a four-state simulator. A 32-bit destination can
then contain `000000x7` and fail `$isunknown`, while the old four-bit read
retained just `7`. This explains why the original topology could run while an
earlier streaming testbench failed at label index 0. Two-state simulation can
hide the unknown bits, so the label regression also has Icarus four-state
coverage.

If a generated project reports this error, update the checkout and any imported
copy of `common/mlp_variant_tb.sv`, close the failed simulation, and launch it
again to rebuild the snapshot. Running `run all` after a fatal stop continues
the old failed run; it does not load the corrected testbench.

## Reproduce the split

Extract `test_files.zip` outside the checkout and run from the repository root:

```sh
python3 scripts/split_mnist_mem.py \
    /path/to/test_samples_10k.mem /path/to/test_labels_10k.mem \
    /path/to/new/mnist_batches
```

The output directory must not already exist. The splitter validates exactly
10,000 images, 784 eight-digit hexadecimal pixels per image, and labels 0–9
(with optional `0x` prefixes). Invalid or truncated inputs do not publish a
partial batch directory. The complete source memories are not duplicated in
Git; only their smaller batches and integrity manifest are stored here.

Splitter regression checks:

```sh
/workspace/mlp-env/bin/python tests/test_mnist_batches.py
```

The source/outputs have also been independently checked byte-for-byte. Tests
using a lightweight simulation model exercise all 1,000 transfers in the last
batch; short runs with real topology models check selected batches separately.
These checks do not claim a full 10,000-image accuracy evaluation or a
Vivado/XSim run.
