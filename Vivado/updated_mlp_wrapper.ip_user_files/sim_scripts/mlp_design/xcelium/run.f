-makelib xcelium_lib/xilinx_vip -sv \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_if.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/clk_vip_if.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/rst_vip_if.sv" \
-endlib
-makelib xcelium_lib/xpm -sv \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \
-endlib
-makelib xcelium_lib/xpm \
  "/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \
-endlib
-makelib xcelium_lib/axi_infrastructure_v1_1_0 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_vip_v1_1_13 -sv \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ffc2/hdl/axi_vip_v1_1_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/processing_system7_vip_v1_0_15 -sv \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/mlp_design/ip/mlp_design_processing_system7_0_0/sim/mlp_design_processing_system7_0_0.v" \
  "../../../bd/mlp_design/ip/mlp_design_mlp_0_0/sim/mlp_design_mlp_0_0.v" \
-endlib
-makelib xcelium_lib/lib_pkg_v1_0_2 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/0513/hdl/lib_pkg_v1_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_7 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/83df/simulation/fifo_generator_vlog_beh.v" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_7 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/83df/hdl/fifo_generator_v13_2_rfs.vhd" \
-endlib
-makelib xcelium_lib/fifo_generator_v13_2_7 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/83df/hdl/fifo_generator_v13_2_rfs.v" \
-endlib
-makelib xcelium_lib/lib_fifo_v1_0_16 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/6c82/hdl/lib_fifo_v1_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/lib_srl_fifo_v1_0_2 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/51ce/hdl/lib_srl_fifo_v1_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/lib_cdc_v1_0_2 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ef1e/hdl/lib_cdc_v1_0_rfs.vhd" \
-endlib
-makelib xcelium_lib/axi_datamover_v5_1_29 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/2237/hdl/axi_datamover_v5_1_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/axi_sg_v4_1_15 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/751a/hdl/axi_sg_v4_1_rfs.vhd" \
-endlib
-makelib xcelium_lib/axi_dma_v7_1_28 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/70c4/hdl/axi_dma_v7_1_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/mlp_design/ip/mlp_design_axi_dma_0_0/sim/mlp_design_axi_dma_0_0.vhd" \
-endlib
-makelib xcelium_lib/proc_sys_reset_v5_0_13 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/8842/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/mlp_design/ip/mlp_design_rst_ps7_0_100M_0/sim/mlp_design_rst_ps7_0_100M_0.vhd" \
-endlib
-makelib xcelium_lib/generic_baseblocks_v2_1_0 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/b752/hdl/generic_baseblocks_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_register_slice_v2_1_27 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/f0b4/hdl/axi_register_slice_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_data_fifo_v2_1_26 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/3111/hdl/axi_data_fifo_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/axi_crossbar_v2_1_28 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/c40e/hdl/axi_crossbar_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/mlp_design/ip/mlp_design_xbar_0/sim/mlp_design_xbar_0.v" \
-endlib
-makelib xcelium_lib/axi_protocol_converter_v2_1_27 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/aeb3/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/mlp_design/ip/mlp_design_auto_pc_0/sim/mlp_design_auto_pc_0.v" \
-endlib
-makelib xcelium_lib/axi_clock_converter_v2_1_26 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/b8be/hdl/axi_clock_converter_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/blk_mem_gen_v8_4_5 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/25a8/simulation/blk_mem_gen_v8_4.v" \
-endlib
-makelib xcelium_lib/axi_dwidth_converter_v2_1_27 \
  "../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/4675/hdl/axi_dwidth_converter_v2_1_vl_rfs.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  "../../../bd/mlp_design/ip/mlp_design_auto_us_0/sim/mlp_design_auto_us_0.v" \
  "../../../bd/mlp_design/ip/mlp_design_auto_us_1/sim/mlp_design_auto_us_1.v" \
  "../../../bd/mlp_design/ip/mlp_design_auto_pc_1/sim/mlp_design_auto_pc_1.v" \
  "../../../bd/mlp_design/sim/mlp_design.v" \
-endlib
-makelib xcelium_lib/xil_defaultlib \
  glbl.v
-endlib

