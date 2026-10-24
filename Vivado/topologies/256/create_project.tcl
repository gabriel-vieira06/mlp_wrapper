# Create the 784 -> 256 -> 10 Vivado project.
# Arguments: optional output directory, then optional memory directory.
set topology_variant_dir [file dirname [file normalize [info script]]]
source [file join $topology_variant_dir .. .. .. scripts create_topology_project.tcl]
::mlp_topology_project::create $topology_variant_dir $argv
