#!/bin/bash

#source /opt/Xilinx/Vivado/2019.2/settings64.sh
source /opt/Xilinx/Vivado/2020.2/settings64.sh


xelab tb_tfacc_core glbl -timescale 1ns/1ns -prj tb_tfacc_core.prj -L unisims_ver -s tb_tfacc_core_2 -sv_lib dpi

xsim  tb_tfacc_core_2 -R -testplusarg b=0 -testplusarg e=9  --log xsim-1.log > /dev/null &
# wait for xsimk was invoked.
#   xsim.dir/tb_tfacc_core_2/xsim_script.tcl is reused.
sleep 30

xsim  tb_tfacc_core_2 -R -testplusarg b=10 -testplusarg e=19 --log xsim-2.log > /dev/null &
sleep 30

xsim  tb_tfacc_core_2 -R -testplusarg b=20 -testplusarg e=29 --log xsim-3.log > /dev/null &
sleep 30

xsim  tb_tfacc_core_2 -R -testplusarg b=30 -testplusarg e=34 --log xsim-4.log > /dev/null &
sleep 30


