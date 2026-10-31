# mlp_wrapper

MNIST MLP accelerator for the PYNQ-Z1, with a PyTorch training/export notebook
and a Vivado 2022.2 project.

See [resource optimization and verification](docs/resource_optimization.md) for
the block RAM implementation, simulation checks, and reproducible synthesis
commands.

Alternative hidden-layer sizes `500_500`, `256_128`, `256`, and `512_256_128`
are available under [Vivado/topologies](Vivado/topologies/README.md), with
separate Vivado project-creation scripts and memory-file requirements.
The supplied weight and bias files are included in each topology's `mem/`
directory and selected automatically by those scripts.
