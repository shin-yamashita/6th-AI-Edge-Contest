#!/bin/bash

source xilinx_env.sh

# simulation run stage 0 ~ 71

stage=0 # stage from
endst=0 # stage to
if [ $# -ge 1 ]; then
  stage=$1
  endst=$2
fi
#echo $stage $endst > stage.in

xelab tb_tfacc_core glbl -timescale 1ns/1ns -prj tb_tfacc_core.prj -L unisims_ver -s tb_tfacc_core_r -sv_lib dpi
xsim tb_tfacc_core_r -testplusarg b=$stage -testplusarg e=$endst -R --log xsim-r.log

