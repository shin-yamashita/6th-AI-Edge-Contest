#!/bin/bash

function chkerr
{
 if [ $? != 0 ] ; then
  echo "***** error exit ******"
  exit
 fi
}

#prj=dec
prj=rv32_core
if [ $# = 1 ] ; then
 prj=$1
fi

source xilinx_env.sh

echo Simulation Tool: Viavdo Simulator $prj

xsim -g -wdb tb_$prj.wdb tb_$prj

chkerr

echo done

