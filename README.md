# mlp_wrapper

MNIST MLP accelerator for the PYNQ-Z1, with a PyTorch training/export notebook
and a Vivado 2022.2 project.

See the [scripts guide](scripts/README.md) for project creation, MNIST batch
preparation and standalone synthesis commands. The topology work is maintained
on the single `topologies` branch.

See [resource optimization and verification](docs/resource_optimization.md) for
the block RAM implementation, simulation checks, and reproducible synthesis
commands.

The [Vivado topology presets](Vivado/topologies/README.md) include `64_32`,
`500_500`, `256_128`, `256`, and `512_256_128`. Each project script selects
its trained weights and biases and configures the shared MNIST batch testbench.
Run this command from the repository root to generate the `64_32` project.

```sh
vivado -mode batch -source Vivado/topologies/64_32/create_project.tcl
```

Open `../mlp_64_32_vivado/mlp_64_32.xpr` for the shared simulation workflow.
The original project is available at `Vivado/updated_mlp_wrapper.xpr`.
