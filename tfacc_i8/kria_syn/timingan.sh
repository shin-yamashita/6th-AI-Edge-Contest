#!/bin/bash

#source /opt/Xilinx/Vivado/2014.4/settings32.sh
#source /opt/Xilinx/Vivado/2016.4/settings64.sh
#source /opt/Xilinx/Vivado/2019.2/settings64.sh
#source /opt/Xilinx/Vivado/2020.2/settings64.sh
source xilinx_env.sh

vivado -mode tcl << EOF

open_checkpoint rev/post_route.dcp
start_gui
report_timing_summary -delay_type min_max -report_unconstrained -check_timing_verbose -max_paths 100 -nworst 2 -input_pins -name timing_1

EOF


