# Standalone resource comparison for the custom MLP, using Vivado 2022.2.
# From the repository root (do not reuse the checked-in generated project):
#   vivado -mode batch -nojournal -nolog -source scripts/synth_luts.tcl \
#       -tclargs /workspace/mlp-synth-after
# Optional second argument: directory containing the RTL and six weight/bias
# files. To compare a baseline Git revision (HEAD below) without changing this
# checkout, export it to a new directory; choose the desired ref in git archive:
#   mkdir -p /workspace/mlp-before
#   git archive HEAD Vivado/updated_mlp_wrapper.srcs/sources_1/new | \
#       tar -x -C /workspace/mlp-before
#   vivado -mode batch -nojournal -nolog -source scripts/synth_luts.tcl \
#       -tclargs /workspace/mlp-synth-before \
#       /workspace/mlp-before/Vivado/updated_mlp_wrapper.srcs/sources_1/new
# Use the same Vivado version and arguments for both runs. Compare the two
# utilization.rpt files and memory_primitives.rpt files. These are standalone
# synthesis estimates, not full-design placed utilization or timing signoff.

if {$argc > 2} {
    error "Usage: synth_luts.tcl ?output_directory? ?rtl_directory?"
}
set repo_dir [file normalize [file join [file dirname [info script]] ..]]
set output_dir [file normalize [file join [file dirname $repo_dir] mlp-synth]]
set rtl_dir [file join $repo_dir Vivado updated_mlp_wrapper.srcs sources_1 new]
if {$argc >= 1} {set output_dir [file normalize [lindex $argv 0]]}
if {$argc == 2} {set rtl_dir [file normalize [lindex $argv 1]]}

# Keep generated checkpoints, reports and staged memory data out of the source
# checkout. Existing output files with these names are replaced on each run.
foreach protected_dir [list $repo_dir $rtl_dir] {
    if {$output_dir eq $protected_dir ||
        [string first "${protected_dir}/" "${output_dir}/"] == 0} {
        error "Output directory must be outside the repository and RTL directory"
    }
}
set sources [list ReLU.sv dense.sv dense_wrapper.sv hard_sigmoid.sv \
    hard_tanh.sv leakyReLU.sv mem_behavioral_B.sv mem_behavioral_W.sv \
    mult2c.sv step.sv mlp.v]
set memories [list H1W.mem H1B.mem H2W.mem H2B.mem H3W.mem H3B.mem]
foreach name [concat $sources $memories] {
    if {![file isfile [file join $rtl_dir $name]]} {
        error "Missing input: [file join $rtl_dir $name]"
    }
}
file mkdir $output_dir
foreach name $memories {
    file copy -force [file join $rtl_dir $name] [file join $output_dir $name]
}
cd $output_dir

create_project -in_memory -part xc7z020clg400-1
set_property target_language Verilog [current_project]
foreach name $sources {read_verilog -sv [file join $rtl_dir $name]}
add_files -norecurse $memories

# Provide the 50 MHz clock before synthesis so timing-driven mapping sees the
# actual target period, rather than constraining only the resulting netlist.
set clock_xdc [open clock.xdc w]
puts $clock_xdc {create_clock -name mlp_clk -period 20.000 [get_ports clk]}
close $clock_xdc
read_xdc clock.xdc
synth_design -top mlp -part xc7z020clg400-1 -flatten_hierarchy rebuilt

set_input_delay -clock mlp_clk 0.0 \
    [get_ports {rst_n s_axis_tdata[*] s_axis_tvalid s_axis_tlast m_axis_tready}]
set_output_delay -clock mlp_clk 0.0 \
    [get_ports {s_axis_tready m_axis_tdata[*] m_axis_tvalid m_axis_tlast dbg_valid_in dbg_valid_out}]
report_utilization -file utilization.rpt
report_utilization -hierarchical -hierarchical_depth 5 -file utilization_hierarchical.rpt
report_timing_summary -delay_type min_max -report_unconstrained \
    -check_timing_verbose -file timing_summary.rpt
write_checkpoint -force mlp_synth.dcp

# Explicit primitive evidence complements utilization counts: an inferred block
# ROM/RAM appears as RAMB18E1 or RAMB36E1, rather than a LUT read mux.
set ram_cells [get_cells -quiet -hierarchical \
    -filter {REF_NAME =~ RAMB* || REF_NAME =~ RAMD* || REF_NAME =~ RAMS*}]
set report [open memory_primitives.rpt w]
puts $report "Vivado: [version -short]"
puts $report "RTL directory: $rtl_dir"
puts $report "Part: xc7z020clg400-1; top: mlp; clock period: 20 ns"
puts $report "Memory primitives: [llength $ram_cells]"
foreach cell [lsort $ram_cells] {
    puts $report "[get_property REF_NAME $cell]\t$cell"
}
close $report
puts "Standalone MLP reports written to $output_dir"
