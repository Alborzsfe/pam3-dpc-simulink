# vivado -mode batch -source vivado/create_project.tcl -tclargs PART LANES DC ADAPT
# Default part is an EXAMPLE, not a board or procurement recommendation.
set root [file normalize [file join [file dirname [info script]] ..]]
set part xc7a200tfbg484-2
set lanes 8
set dc 0
set adaptive 0
if {[llength $argv]>0} {set part [lindex $argv 0]}
if {[llength $argv]>1} {set lanes [lindex $argv 1]}
if {[llength $argv]>2} {set dc [lindex $argv 2]}
if {[llength $argv]>3} {set adaptive [lindex $argv 3]}
if {$lanes!=1 && $lanes!=8} {error "LANES must be 1 or 8"}
set project_dir [file join $root vivado build project]
create_project -force pam3_analyzer $project_dir -part $part
add_files -norecurse [glob [file join $root rtl *.sv]]
set_property top pam3_analyzer_core [current_fileset]
set_property generic "LANES=$lanes DC_ENABLE=$dc ADAPTIVE=$adaptive" [current_fileset]
set_property target_language Verilog [current_project]
set_property simulator_language Mixed [current_project]
add_files -fileset constrs_1 -norecurse [file join $root vivado example_ooc.xdc]
update_compile_order -fileset sources_1
puts "Created portable digital-core project: $project_dir"
puts "No board pins, ADC PHY, USB controller or bitstream are configured."
