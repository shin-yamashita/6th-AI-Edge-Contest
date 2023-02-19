#
# build.tcl
# non-project batch flow
#
# NOTE:  typical usage would be "vivado -mode tcl -source build.tcl" 
#
# STEP#0: define output directory area.
#

proc runPPO { {numIters 1} {enablePhysOpt 1} } {
  for {set i 0} {$i < $numIters} {incr i} {
    place_design -post_place_opt
      if {$enablePhysOpt != 0} {
      phys_opt_design
    }
    route_design
    if {[get_property SLACK [get_timing_paths ]] >= 0} {break}; #stop if timing is met
  }
}

#create_project -in_memory -part xczu3eg-sbva484-1-i
#set_property board_part avnet.com:ultra96v2:part0:1.2 [current_project]
#set_property source_mgmt_mode All [current_project]

create_project -in_memory  -part xck26-sfvc784-2LV-c
set_property board_part xilinx.com:kv260_som:part0:1.2 [current_project]
set_property source_mgmt_mode All [current_project]

set CWD [pwd]
set proj design_1_wrapper
set proj_2 design_1_wrapper_2

set outputDir ./rev
#file mkdir $outputDir
#
# STEP#1: setup design sources and constraints
#

open_checkpoint $outputDir/post_route.dcp

runPPO 4 1 ; # run 4 post-route iterations and enable phys_opt_design

write_checkpoint -force $outputDir/post2_route
report_timing_summary -file $outputDir/post2_route_timing_summary.rpt
report_timing -sort_by group -max_paths 100 -path_type summary -file $outputDir/post2_route_timing.rpt
report_clock_utilization -file $outputDir/post2_clock_util.rpt
report_utilization -file $outputDir/post2_route_util.rpt
report_utilization -hierarchical -file $outputDir/post2_route_area.rpt
report_power -file $outputDir/post2_route_power.rpt
report_drc -file $outputDir/post2_imp_drc.rpt


#write_verilog -force $outputDir/bft_impl_netlist.v
#write_xdc -no_fixed_only -force $outputDir/bft_impl.xdc
#
# STEP#5: generate a bitstream
# 

write_bitstream -force $outputDir/$proj_2.bit
write_hwdef -force -file $outputDir/$proj_2.hwdef

exit

