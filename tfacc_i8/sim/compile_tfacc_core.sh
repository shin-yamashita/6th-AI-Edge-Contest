#!/bin/bash

source xilinx_env.sh

xelab -timescale 1ns/1ns tb_tfacc_core glbl -L unisims_ver -dpiheader dpi.h
xsc c_main.c

xelab tb_tfacc_core glbl -timescale 1ns/1ns -prj tb_tfacc_core.prj -L unisims_ver -sv_lib dpi -s tb_tfacc_core -debug typical 

