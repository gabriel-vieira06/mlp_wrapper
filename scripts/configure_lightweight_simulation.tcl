# Source this file in an open Vivado project before launching simulation:
#   source /absolute/path/to/mlp_wrapper/scripts/configure_lightweight_simulation.tcl
# Existing simulations must be closed and relaunched to rebuild the snapshot.
# This profile keeps the selected batch and the RTL unchanged.

namespace eval ::mlp_lightweight_simulation {
    variable runtime_script [file join [file dirname [file normalize [info script]]] xsim_run_batch.tcl]
}

proc ::mlp_lightweight_simulation::configure {{fileset_name sim_1}} {
    variable runtime_script
    foreach command {get_projects get_filesets get_files list_property set_property} {
        if {![llength [info commands ::$command]]} {
            error "Lightweight simulation requires an open Vivado project (missing command: $command)."
        }
    }
    if {![llength [::get_projects -quiet]]} {
        error "Open a Vivado project before configuring lightweight simulation."
    }
    set fileset [::get_filesets -quiet $fileset_name]
    if {[llength $fileset] != 1} {
        error "Lightweight simulation requires exactly one simulation fileset named $fileset_name."
    }
    if {![file isfile $runtime_script]} {
        error "Missing lightweight simulation runtime script: $runtime_script"
    }

    # Validate all required settings before changing any property. Vivado may
    # report property names in upper case; property lookup is case insensitive.
    set properties [::list_property $fileset]
    set settings [list \
        xsim.elaborate.debug_level off \
        xsim.simulate.log_all_signals false \
        xsim.simulate.custom_tcl $runtime_script]
    set missing [list]
    foreach {property value} $settings {
        if {[lsearch -exact -nocase $properties $property] < 0} {
            lappend missing $property
        }
    }
    # Vivado's XSim launcher includes enabled waveform configurations even
    # with a custom runtime script. Disable those project entries, preserving
    # their files so users can re-enable them for a later debug session.
    set waveform_files [::get_files -quiet -of_objects $fileset -filter {IS_ENABLED == 1} *.wcfg]
    foreach waveform $waveform_files {
        if {[lsearch -exact -nocase [::list_property $waveform] IS_ENABLED] < 0} {
            lappend missing "IS_ENABLED on $waveform"
        }
    }
    if {[llength $missing]} {
        error "Cannot configure lightweight simulation: fileset $fileset_name does not support [join $missing {, }]. This profile requires the Vivado XSim simulation properties. No profile settings were changed."
    }
    # A previously saved waveform configuration can request more signals when
    # the GUI opens. Clear it when this Vivado version exposes the property.
    if {[lsearch -exact -nocase $properties xsim.view] >= 0} {
        lappend settings xsim.view {}
    }
    ::set_property -dict $settings $fileset
    if {[llength $waveform_files]} {
        ::set_property IS_ENABLED false $waveform_files
        puts "Disabled saved waveform configurations for lightweight simulation: [join $waveform_files {, }]"
    }
    puts "Lightweight XSim profile configured for $fileset_name. Close and relaunch simulation to apply it; batch selection and NUM_TESTS are unchanged."
}

::mlp_lightweight_simulation::configure
