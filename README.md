# mlp_wrapper

MNIST MLP accelerator for the PYNQ-Z1, with a PyTorch training/export notebook
and a Vivado 2022.2 project.

See the [PYNQ-Z1 validation notebooks](PYNQ/notebooks/README.md) to benchmark
the five topology overlays on the board with all ten MNIST test batches.

See the [scripts guide](scripts/README.md) for project creation, MNIST batch
preparation and standalone synthesis commands. The topology work is maintained
on the single `topologies` branch.

See [resource optimization and verification](docs/resource_optimization.md) for
the block RAM implementation, simulation checks, and reproducible synthesis
commands.

Alternative hidden-layer sizes `500_500`, `256_128`, `256`, and `512_256_128`
are available under [Vivado/topologies](Vivado/topologies/README.md), with
separate Vivado project-creation scripts and memory-file requirements.
The supplied weight and bias files are included in each topology's `mem/`
directory and selected automatically by those scripts.
