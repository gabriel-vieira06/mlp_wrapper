// Copyright 1986-2022 Xilinx, Inc. All Rights Reserved.
// --------------------------------------------------------------------------------
// Tool Version: Vivado v.2022.2 (lin64) Build 3671981 Fri Oct 14 04:59:54 MDT 2022
// Date        : Sun May  3 13:33:50 2026
// Host        : bazzite running 64-bit unknown
// Command     : write_verilog -force -mode synth_stub -rename_top decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix -prefix
//               decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix_ design_1_design_wrapper_0_1_stub.v
// Design      : design_1_design_wrapper_0_1
// Purpose     : Stub declaration of top-level module interface
// Device      : xc7z020clg400-1
// --------------------------------------------------------------------------------

// This empty module with port declaration file causes synthesis tools to infer a black box for IP.
// The synthesis directives are for Synopsys Synplify support to prevent IO buffer insertion.
// Please paste the declaration into a Verilog source file or add the file as an additional source.
(* X_CORE_INFO = "design_wrapper,Vivado 2022.2" *)
module decalper_eb_ot_sdeen_pot_pi_dehcac_xnilix(clk, rst, data_in, data_valid, data_out, 
  data_out_valid, data_out_last)
/* synthesis syn_black_box black_box_pad_pin="clk,rst,data_in[31:0],data_valid,data_out[31:0],data_out_valid,data_out_last" */;
  input clk;
  input rst;
  input [31:0]data_in;
  input data_valid;
  output [31:0]data_out;
  output data_out_valid;
  output data_out_last;
endmodule
