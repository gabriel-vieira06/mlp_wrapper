#!/usr/bin/env python3
"""Check the Vivado profile's Tcl control flow with explicit command stubs.

Run: python3 tests/test_lightweight_simulation.py
These tests do not replace launching XSim in an installed Vivado 2022.2.
"""

from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


REPO = Path(__file__).resolve().parents[1]
PROFILE = REPO / "scripts/configure_lightweight_simulation.tcl"
RUNTIME = REPO / "scripts/xsim_run_batch.tcl"

STUBS = r"""
set profile [lindex $argv 0]
set output_dir [lindex $argv 1]
set repo_dir [lindex $argv 2]
set projects {test_project}
set filesets {sim_1}
set properties {XSIM.ELABORATE.DEBUG_LEVEL XSIM.SIMULATE.LOG_ALL_SIGNALS XSIM.SIMULATE.CUSTOM_TCL XSIM.VIEW}
set waveform_files {}
set waveform_properties {IS_ENABLED}
set mutations {}
proc get_projects {args} {return $::projects}
proc get_filesets {args} {
    set name [lindex $args end]
    if {$name in $::filesets} {return $name}
    return {}
}
proc get_files {args} {return $::waveform_files}
proc list_property {object} {
    if {$object in $::waveform_files} {return $::waveform_properties}
    return $::properties
}
proc set_property {args} {lappend ::mutations $args}
proc assert {condition message} {
    if {![uplevel 1 [list expr $condition]]} {error $message}
}
proc assert_profile {} {
    set matches {}
    foreach mutation $::mutations {
        if {[lindex $mutation 0] eq "-dict" && [dict exists [lindex $mutation 1] xsim.elaborate.debug_level]} {
            lappend matches $mutation
        }
    }
    assert {[llength $matches] == 1} {Expected one profile mutation}
    set mutation [lindex $matches 0]
    assert {[lindex $mutation 2] eq "sim_1"} {Wrong simulation fileset}
    set settings [lindex $mutation 1]
    assert {[dict get $settings xsim.elaborate.debug_level] eq "off"} {Debug must be off}
    assert {[dict get $settings xsim.simulate.log_all_signals] eq "false"} {Bulk logging must be off}
    set runtime [dict get $settings xsim.simulate.custom_tcl]
    assert {[file pathtype $runtime] eq "absolute"} {Runtime path must be absolute}
    assert {$runtime eq [file join [file dirname $::profile] xsim_run_batch.tcl]} {Wrong runtime path}
    return $settings
}
"""

PROJECT_STUBS = r"""
set projects {}
set filesets {sim_1 sources_1}
set design {}
set cells {}
set simulation_files {}
set rtl_files {}
proc version {args} {return 2022.2}
proc create_project {name output args} {set ::projects [list $name]}
proc current_project {} {return [lindex $::projects 0]}
proc add_files {args} {
    if {[lsearch -exact $args -fileset] >= 0} {
        set ::simulation_files [concat $::simulation_files [lindex $args end]]
    } else {
        set ::rtl_files [concat $::rtl_files [lindex $args end]]
    }
}
proc update_compile_order {args} {}
namespace eval ::common {proc send_gid_msg {args} {}}
proc current_bd_design {args} {
    if {[llength $args] && [lindex $args 0] ne "-quiet"} {set ::design [lindex $args 0]}
    return $::design
}
proc create_bd_design {name} {set ::design $name}
proc get_bd_cells {args} {
    if {$args eq "-quiet"} {return $::cells}
    set name [lindex $args end]
    if {$name eq "/" || $name in $::cells} {return $name}
    return {}
}
proc get_files {args} {
    if {[lindex $args end] eq "*.wcfg"} {return $::waveform_files}
    if {$::design ne "" && [string match *mlp_design.bd [lindex $args end]]} {
        return [file join $::output_dir mlp_design.bd]
    }
    return {}
}
proc get_ipdefs {args} {return [lindex $args end]}
proc can_resolve_reference {name} {return 1}
proc get_property {property object} {
    if {$property eq "TYPE"} {return hier}
    return $object
}
proc current_bd_instance {args} {return /}
proc create_bd_intf_port {args} {return [lindex $args end]}
proc create_bd_cell {args} {
    set name [lindex $args end]
    lappend ::cells $name
    return $name
}
foreach command {get_bd_intf_pins get_bd_intf_ports get_bd_pins get_bd_addr_spaces get_bd_addr_segs} {
    proc $command {args} {return [lindex $args end]}
}
foreach command {connect_bd_intf_net connect_bd_net assign_bd_address validate_bd_design save_bd_design generate_target} {
    proc $command {args} {}
}
proc make_wrapper {args} {return [file join $::output_dir mlp_design_wrapper.v]}
proc launch_runs {args} {error {Project creation must not launch synthesis}}
proc synth_design {args} {error {Project creation must not launch synthesis}}
"""


@unittest.skipUnless(shutil.which("tclsh"), "tclsh is required")
class LightweightSimulationTests(unittest.TestCase):
    def run_tcl(self, body, profile=PROFILE):
        with tempfile.TemporaryDirectory(prefix="mlp-profile-test-") as temporary:
            script = Path(temporary) / "check.tcl"
            script.write_text(STUBS + "\nif {[catch {\n" + body + r"""
} message options]} {
    puts stderr $message
    puts stderr [dict get $options -errorinfo]
    exit 1
}
""")
            result = subprocess.run(
                ["tclsh", str(script), str(profile), str(Path(temporary) / "project"), str(REPO)],
                capture_output=True, text=True, timeout=30,
            )
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)

    def test_standalone_source_validates_case_insensitive_properties_and_applies_once(self):
        self.run_tcl(r"""
source $profile
set settings [assert_profile]
assert {[dict get $settings xsim.view] eq ""} {Saved view must be cleared when supported}
assert {[llength $mutations] == 1} {Profile must use one set_property operation}
""")

    def test_source_from_creator_namespace(self):
        self.run_tcl(r"""
namespace eval ::mlp_topology_project {source $::profile}
assert_profile
assert {[llength [info commands ::mlp_lightweight_simulation::configure]] == 1} {Helper must use its absolute namespace}
""")

    def test_optional_waveform_view_property_is_not_required(self):
        self.run_tcl(r"""
set properties [lrange $properties 0 2]
source $profile
set settings [assert_profile]
assert {![dict exists $settings xsim.view]} {Unsupported optional property was set}
""")

    def test_enabled_saved_waveforms_are_disabled_without_removing_files(self):
        self.run_tcl(r"""
set waveform_files {debug.wcfg {debug session/saved.wcfg}}
source $profile
assert_profile
assert {[llength $mutations] == 2} {Expected profile setup and waveform disabling}
assert {[lindex $mutations 1] eq [list IS_ENABLED false $waveform_files]} {Saved waveform entries must be disabled}
""")

    def test_unsupported_waveform_property_fails_before_any_mutation(self):
        self.run_tcl(r"""
set waveform_files {debug.wcfg}
set waveform_properties {}
assert {[catch {source $profile} message]} {Unsupported waveform property must fail}
assert {[string match {*IS_ENABLED on debug.wcfg*} $message]} {Failure must identify the waveform property}
assert {[llength $mutations] == 0} {Waveform validation partially changed settings}
""")

    def test_each_missing_required_property_fails_before_mutation(self):
        for missing in ("XSIM.ELABORATE.DEBUG_LEVEL", "XSIM.SIMULATE.LOG_ALL_SIGNALS", "XSIM.SIMULATE.CUSTOM_TCL"):
            with self.subTest(property=missing):
                self.run_tcl("set missing {" + missing + r"""}
set properties [lreplace $properties [lsearch -exact $properties $missing] [lsearch -exact $properties $missing]]
assert {[catch {source $profile} message]} {Unsupported profile must fail}
assert {[string match *[string tolower $missing]* $message]} {Failure must identify the unsupported property}
assert {[llength $mutations] == 0} {Unsupported profile partially changed settings}
""")

    def test_requires_an_open_project(self):
        self.run_tcl(r"""
set projects {}
assert {[catch {source $profile} message]} {No-project setup must fail}
assert {[string match {Open a Vivado project*} $message]} {Unclear no-project error}
assert {[llength $mutations] == 0} {No-project setup changed settings}
""")

    def test_requires_simulation_fileset(self):
        self.run_tcl(r"""
set filesets {}
assert {[catch {source $profile} message]} {Missing fileset must fail}
assert {[string match {*fileset named sim_1*} $message]} {Unclear fileset error}
assert {[llength $mutations] == 0} {Missing fileset setup changed settings}
""")

    def test_missing_runtime_fails_before_mutation(self):
        with tempfile.TemporaryDirectory(prefix="mlp-profile-runtime-") as temporary:
            profile = Path(temporary) / PROFILE.name
            shutil.copyfile(PROFILE, profile)
            self.run_tcl(r"""
assert {[catch {source $profile} message]} {Missing runtime must fail}
assert {[string match {Missing lightweight simulation runtime script:*} $message]} {Unclear runtime error}
assert {[llength $mutations] == 0} {Missing runtime partially changed settings}
""", profile)

    def test_runtime_only_runs_until_testbench_finishes(self):
        commands = [line.strip() for line in RUNTIME.read_text().splitlines()
                    if line.strip() and not line.lstrip().startswith("#")]
        self.assertEqual(commands, ["run all"])

    def test_creator_preserves_batch_defaults_sources_and_50_mhz(self):
        for topology, override_memories in (("256", False), ("64_32", False), ("64_32", True)):
            with self.subTest(topology=topology, override_memories=override_memories):
                self.run_tcl(PROJECT_STUBS + f"""
set topology {topology}
set override_memories {int(override_memories)}
""" + r"""
set topology_dir [file join $repo_dir Vivado topologies $topology]
set argv [list $output_dir]
set legacy_memory_dir [file join $repo_dir Vivado updated_mlp_wrapper.srcs sources_1 new]
set legacy_memories {H1W.mem H1B.mem H2W.mem H2B.mem H3W.mem H3B.mem}
set expected_memory_dir $legacy_memory_dir
if {$override_memories} {
    set expected_memory_dir [file join [file dirname $output_dir] custom_memories]
    file mkdir $expected_memory_dir
    foreach name $legacy_memories {
        file copy [file join $legacy_memory_dir $name] $expected_memory_dir
    }
    # Change one valid word to distinguish the override from the legacy default.
    set stream [open [file join $expected_memory_dir H1W.mem] r+b]
    puts -nonewline $stream 87654321
    close $stream
    lappend argv $expected_memory_dir
}
source [file join $topology_dir create_project.tcl]
assert_profile
assert {[llength $simulation_files] == 21} {Expected shared testbench and twenty batch files}
assert {[lindex $simulation_files 0] eq [file join $repo_dir Vivado topologies common mlp_variant_tb.sv]} {Wrong simulation testbench}
foreach name {test_samples test_labels} {
    for {set batch 0} {$batch < 10} {incr batch} {
        set expected ${name}_[format %02d $batch].mem
        assert {[lsearch -glob $simulation_files */$expected] >= 0} {Missing batch simulation source}
    }
}
assert {[lsearch -exact $mutations {generic {BATCH_ID=0 NUM_TESTS=1000} sim_1}] >= 0} {Batch defaults changed}
assert {[lsearch -exact $mutations {top mlp_variant_tb sim_1}] >= 0} {Simulation top changed}
assert {[lsearch -exact $mutations {CONFIG.PCW_FPGA0_PERIPHERAL_FREQMHZ 50 processing_system7_0}] >= 0} {50 MHz clock changed}
assert {[lsearch -exact $rtl_files [file join $topology_dir mlp.v]] >= 0} {Selected RTL adapter missing}
assert {[lsearch -glob $rtl_files */sources_1/new/mlp.v] < 0} {Old fixed topology was imported}
if {$topology eq "64_32"} {
    assert {[llength [lsearch -all -glob $rtl_files *.mem]] == 6} {Expected six memory sources}
    foreach name $legacy_memories {
        set staged [file join $output_dir $name]
        assert {[lsearch -exact $rtl_files $staged] >= 0} "Staged memory $name was not added to the project"
        set expected [open [file join $expected_memory_dir $name] rb]
        set actual [open $staged rb]
        assert {[read $actual] eq [read $expected]} "Staged memory $name differs from its source"
        close $actual
        close $expected
    }
}
""")


if __name__ == "__main__":
    unittest.main(verbosity=2)
