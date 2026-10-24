# Create a clean Vivado 2022.2 PYNQ-Z1 project for a selected topology.
# Entry points live in Vivado/topologies/<name>/create_project.tcl:
#   vivado -mode batch -source Vivado/topologies/256/create_project.tcl \
#       -tclargs /outside/checkout/mlp_256 /path/to/256/mem
# No synthesis, implementation or bitstream run is launched.

namespace eval ::mlp_topology_project {
    variable hidden_sizes [dict create \
        500_500 {500 500} \
        256_128 {256 128} \
        256 {256} \
        512_256_128 {512 256 128}]
}

proc ::mlp_topology_project::memory_requirements {hidden} {
    set sizes [concat 784 $hidden 10]
    set requirements [dict create]
    for {set layer 1} {$layer < [llength $sizes]} {incr layer} {
        set inputs [lindex $sizes [expr {$layer - 1}]]
        set outputs [lindex $sizes $layer]
        dict set requirements H${layer}W.mem [expr {$inputs * $outputs}]
        dict set requirements H${layer}B.mem $outputs
    }
    return $requirements
}

proc ::mlp_topology_project::validate_memories {mem_dir requirements} {
    set missing [list]
    dict for {name expected} $requirements {
        if {![file isfile [file join $mem_dir $name]]} {
            lappend missing "$name ($expected words)"
        }
    }
    if {[llength $missing]} {
        error "Missing topology memory files in $mem_dir: [join $missing {, }]. Supply this topology's files; 64_32 files are not a substitute."
    }
    dict for {name expected} $requirements {
        set path [file join $mem_dir $name]
        set stream [open $path r]
        set words 0
        set line_number 0
        set status [catch {
            while {[gets $stream line] >= 0} {
                incr line_number
                set word [string trim $line]
                if {$word eq ""} {continue}
                if {![regexp {^[0-9a-fA-F]{8}$} $word]} {
                    error "Invalid 32-bit word in $path at line $line_number: expected exactly eight hexadecimal digits per nonempty line."
                }
                incr words
            }
        } message options]
        close $stream
        if {$status} {return -options $options $message}
        if {$words != $expected} {
            error "Wrong memory size for $path: expected $expected 32-bit words, found $words."
        }
    }
}

proc ::mlp_topology_project::create {variant_dir argv} {
    variable hidden_sizes
    if {[llength $argv] > 2} {
        error "Usage: create_project.tcl ?output_directory? ?memory_directory?"
    }
    set variant_dir [file normalize $variant_dir]
    set variant [file tail $variant_dir]
    if {![dict exists $hidden_sizes $variant]} {
        error "Unknown topology: $variant"
    }
    set repo_dir [file normalize [file join $variant_dir .. .. ..]]
    set output_dir [file normalize [file join [file dirname $repo_dir] mlp_${variant}_vivado]]
    set mem_dir [file join $variant_dir mem]
    if {[llength $argv] >= 1} {set output_dir [file normalize [lindex $argv 0]]}
    if {[llength $argv] == 2} {set mem_dir [file normalize [lindex $argv 1]]}
    if {$output_dir eq $repo_dir || [string first "${repo_dir}/" "${output_dir}/"] == 0} {
        error "Output directory must be outside the repository: $output_dir"
    }
    if {[file exists $output_dir]} {
        if {![file isdirectory $output_dir]} {error "Output path is not a directory: $output_dir"}
        foreach entry [glob -nocomplain -tails -directory $output_dir * .*] {
            if {$entry ni {. ..}} {
                error "Refusing to overwrite nonempty output directory: $output_dir"
            }
        }
    }

    # All input checks happen before create_project or any output is written.
    set requirements [memory_requirements [dict get $hidden_sizes $variant]]
    validate_memories $mem_dir $requirements
    set rtl_dir [file join $repo_dir Vivado updated_mlp_wrapper.srcs sources_1 new]
    set sources [list]
    foreach name {ReLU.sv dense.sv hard_sigmoid.sv hard_tanh.sv leakyReLU.sv mem_behavioral_B.sv mem_behavioral_W.sv mult2c.sv step.sv} {
        lappend sources [file join $rtl_dir $name]
    }
    lappend sources [file join $repo_dir Vivado topologies common mlp_topology.sv]
    lappend sources [file join $variant_dir mlp.v]
    set simulation_sources [list \
        [file join $repo_dir Vivado topologies common mlp_variant_tb.sv] \
        [file join $repo_dir Vivado updated_mlp_wrapper.srcs sim_1 new test_samples.mem] \
        [file join $repo_dir Vivado updated_mlp_wrapper.srcs sim_1 new test_labels.mem]]
    set bd_script [file join $repo_dir PYNQ mlp.tcl]
    foreach path [concat $sources $simulation_sources [list $bd_script]] {
        if {![file isfile $path]} {error "Missing project source: $path"}
    }
    if {![llength [info commands create_project]] || ![llength [info commands version]]} {
        error "Run this script inside Vivado 2022.2."
    }
    if {[string first 2022.2 [version -short]] != 0} {
        error "The block-design export requires Vivado 2022.2; current version: [version -short]."
    }
    if {[llength [get_projects -quiet]]} {
        error "Close the current Vivado project before creating this topology project."
    }

    file mkdir $output_dir
    set old_directory [pwd]
    set status [catch {
        cd $output_dir
        create_project mlp_$variant $output_dir -part xc7z020clg400-1
        set_property target_language Verilog [current_project]
        set_property simulator_language Mixed [current_project]
        add_files -norecurse $sources
        add_files -fileset sim_1 -norecurse $simulation_sources
        set_property top mlp_variant_tb [get_filesets sim_1]
        dict for {name expected} $requirements {
            set staged [file join $output_dir $name]
            file copy [file join $mem_dir $name] $staged
            add_files -norecurse $staged
        }
        update_compile_order -fileset sources_1

        # This export supplies the complete original PS DDR/MIO and DMA wiring.
        # Its no-project fallback is deliberately avoided by creating ours first.
        source $bd_script
        set designs [get_files -quiet */mlp_design.bd]
        if {[llength $designs] != 1 || [llength [get_bd_cells -quiet mlp_0]] != 1} {
            error "Block-design creation failed: expected mlp_design.bd and module reference mlp_0."
        }
        # The old PYNQ export uses 25 MHz; preserve the current project's 50 MHz.
        set_property CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 50 [get_bd_cells processing_system7_0]
        validate_bd_design
        save_bd_design
        generate_target all $designs
        set wrappers [make_wrapper -files $designs -top]
        add_files -norecurse $wrappers
        set_property top mlp_design_wrapper [get_filesets sources_1]
        update_compile_order -fileset sources_1
        update_compile_order -fileset sim_1
        puts "Created [file join $output_dir mlp_${variant}.xpr]"
        puts "Topology: 784 -> [join [dict get $hidden_sizes $variant] { -> }] -> 10; 32-bit weights; FCLK0=50 MHz."
        puts "No synthesis or implementation was run. Device fit depends on the trained memory contents."
    } message options]
    cd $old_directory
    if {$status} {return -options $options $message}
}
