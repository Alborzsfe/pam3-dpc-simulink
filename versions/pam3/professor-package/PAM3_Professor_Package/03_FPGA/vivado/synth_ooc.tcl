# Standalone out-of-context synthesis and OPTIONAL place/route.
# vivado -mode batch -source vivado/synth_ooc.tcl -tclargs PART LANES DC ADAPT ROUTE
set root [file normalize [file join [file dirname [info script]] ..]]
set part xc7a200tfbg484-2
set lanes 8
set dc 0
set adaptive 0
set route 0
foreach {i name} {0 part 1 lanes 2 dc 3 adaptive 4 route} {
    if {[llength $argv]>$i} {set $name [lindex $argv $i]}
}
if {$lanes!=1 && $lanes!=8} {error "LANES must be 1 or 8"}
set out [file join $root vivado build "L${lanes}_DC${dc}_A${adaptive}"]
file mkdir $out
read_verilog -sv [glob [file join $root rtl *.sv]]
synth_design -top pam3_analyzer_core -part $part -mode out_of_context \
    -generic "LANES=$lanes DC_ENABLE=$dc ADAPTIVE=$adaptive"
read_xdc [file join $root vivado example_ooc.xdc]
report_utilization -file [file join $out utilization_synth.rpt]
report_timing_summary -file [file join $out timing_synth.rpt]
report_drc -file [file join $out drc_synth.rpt]
write_checkpoint -force [file join $out synthesized.dcp]
if {$route} {
    opt_design
    place_design
    phys_opt_design
    route_design
    report_utilization -file [file join $out utilization_routed.rpt]
    report_timing_summary -report_unconstrained -file [file join $out timing_routed.rpt]
    report_route_status -file [file join $out route_status.rpt]
    report_drc -file [file join $out drc_routed.rpt]
    write_checkpoint -force [file join $out routed.dcp]
}
puts "Review WNS/TNS, unconstrained paths and interface assumptions in $out"
