#!/bin/sh

# 
# Vivado(TM)
# runme.sh: a Vivado-generated Runs Script for UNIX
# Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
# 

if [ -z "$PATH" ]; then
  PATH=/home/Vieira/Xilinx/Vitis/2022.2/bin:/home/Vieira/Xilinx/Vivado/2022.2/ids_lite/ISE/bin/lin64:/home/Vieira/Xilinx/Vivado/2022.2/bin
else
  PATH=/home/Vieira/Xilinx/Vitis/2022.2/bin:/home/Vieira/Xilinx/Vivado/2022.2/ids_lite/ISE/bin/lin64:/home/Vieira/Xilinx/Vivado/2022.2/bin:$PATH
fi
export PATH

if [ -z "$LD_LIBRARY_PATH" ]; then
  LD_LIBRARY_PATH=
else
  LD_LIBRARY_PATH=:$LD_LIBRARY_PATH
fi
export LD_LIBRARY_PATH

HD_PWD='/var/home/Vieira/Documents/vivado_projects/updated_mlp_wrapper/updated_mlp_wrapper.runs/mlp_design_auto_pc_1_synth_1'
cd "$HD_PWD"

HD_LOG=runme.log
/bin/touch $HD_LOG

ISEStep="./ISEWrap.sh"
EAStep()
{
     $ISEStep $HD_LOG "$@" >> $HD_LOG 2>&1
     if [ $? -ne 0 ]
     then
         exit
     fi
}

EAStep vivado -log mlp_design_auto_pc_1.vds -m64 -product Vivado -mode batch -messageDb vivado.pb -notrace -source mlp_design_auto_pc_1.tcl
