#!/bin/bash

source xilinx_env.sh

tcl=''

if [ $# = 1 ] ; then
 tcl="-source $1"
fi

vivado -mode tcl $tcl

