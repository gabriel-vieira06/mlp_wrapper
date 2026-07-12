vlib modelsim_lib/work
vlib modelsim_lib/msim

vlib modelsim_lib/msim/xilinx_vip
vlib modelsim_lib/msim/xpm
vlib modelsim_lib/msim/axi_infrastructure_v1_1_0
vlib modelsim_lib/msim/axi_vip_v1_1_13
vlib modelsim_lib/msim/processing_system7_vip_v1_0_15
vlib modelsim_lib/msim/xil_defaultlib
vlib modelsim_lib/msim/lib_pkg_v1_0_2
vlib modelsim_lib/msim/fifo_generator_v13_2_7
vlib modelsim_lib/msim/lib_fifo_v1_0_16
vlib modelsim_lib/msim/lib_srl_fifo_v1_0_2
vlib modelsim_lib/msim/lib_cdc_v1_0_2
vlib modelsim_lib/msim/axi_datamover_v5_1_29
vlib modelsim_lib/msim/axi_sg_v4_1_15
vlib modelsim_lib/msim/axi_dma_v7_1_28
vlib modelsim_lib/msim/proc_sys_reset_v5_0_13
vlib modelsim_lib/msim/generic_baseblocks_v2_1_0
vlib modelsim_lib/msim/axi_register_slice_v2_1_27
vlib modelsim_lib/msim/axi_data_fifo_v2_1_26
vlib modelsim_lib/msim/axi_crossbar_v2_1_28
vlib modelsim_lib/msim/axi_protocol_converter_v2_1_27
vlib modelsim_lib/msim/axi_clock_converter_v2_1_26
vlib modelsim_lib/msim/blk_mem_gen_v8_4_5
vlib modelsim_lib/msim/axi_dwidth_converter_v2_1_27

vmap xilinx_vip modelsim_lib/msim/xilinx_vip
vmap xpm modelsim_lib/msim/xpm
vmap axi_infrastructure_v1_1_0 modelsim_lib/msim/axi_infrastructure_v1_1_0
vmap axi_vip_v1_1_13 modelsim_lib/msim/axi_vip_v1_1_13
vmap processing_system7_vip_v1_0_15 modelsim_lib/msim/processing_system7_vip_v1_0_15
vmap xil_defaultlib modelsim_lib/msim/xil_defaultlib
vmap lib_pkg_v1_0_2 modelsim_lib/msim/lib_pkg_v1_0_2
vmap fifo_generator_v13_2_7 modelsim_lib/msim/fifo_generator_v13_2_7
vmap lib_fifo_v1_0_16 modelsim_lib/msim/lib_fifo_v1_0_16
vmap lib_srl_fifo_v1_0_2 modelsim_lib/msim/lib_srl_fifo_v1_0_2
vmap lib_cdc_v1_0_2 modelsim_lib/msim/lib_cdc_v1_0_2
vmap axi_datamover_v5_1_29 modelsim_lib/msim/axi_datamover_v5_1_29
vmap axi_sg_v4_1_15 modelsim_lib/msim/axi_sg_v4_1_15
vmap axi_dma_v7_1_28 modelsim_lib/msim/axi_dma_v7_1_28
vmap proc_sys_reset_v5_0_13 modelsim_lib/msim/proc_sys_reset_v5_0_13
vmap generic_baseblocks_v2_1_0 modelsim_lib/msim/generic_baseblocks_v2_1_0
vmap axi_register_slice_v2_1_27 modelsim_lib/msim/axi_register_slice_v2_1_27
vmap axi_data_fifo_v2_1_26 modelsim_lib/msim/axi_data_fifo_v2_1_26
vmap axi_crossbar_v2_1_28 modelsim_lib/msim/axi_crossbar_v2_1_28
vmap axi_protocol_converter_v2_1_27 modelsim_lib/msim/axi_protocol_converter_v2_1_27
vmap axi_clock_converter_v2_1_26 modelsim_lib/msim/axi_clock_converter_v2_1_26
vmap blk_mem_gen_v8_4_5 modelsim_lib/msim/blk_mem_gen_v8_4_5
vmap axi_dwidth_converter_v2_1_27 modelsim_lib/msim/axi_dwidth_converter_v2_1_27

vlog -work xilinx_vip -64 -incr -mfcu  -sv -L axi_vip_v1_1_13 -L processing_system7_vip_v1_0_15 -L xilinx_vip "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_axi4streampc.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_axi4pc.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/xil_common_vip_pkg.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_pkg.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_pkg.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi4stream_vip_if.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/axi_vip_if.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/clk_vip_if.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/hdl/rst_vip_if.sv" \

vlog -work xpm -64 -incr -mfcu  -sv -L axi_vip_v1_1_13 -L processing_system7_vip_v1_0_15 -L xilinx_vip "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_cdc/hdl/xpm_cdc.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_fifo/hdl/xpm_fifo.sv" \
"/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_memory/hdl/xpm_memory.sv" \

vcom -work xpm -64 -93  \
"/home/Vieira/Xilinx/Vivado/2022.2/data/ip/xpm/xpm_VCOMP.vhd" \

vlog -work axi_infrastructure_v1_1_0 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl/axi_infrastructure_v1_1_vl_rfs.v" \

vlog -work axi_vip_v1_1_13 -64 -incr -mfcu  -sv -L axi_vip_v1_1_13 -L processing_system7_vip_v1_0_15 -L xilinx_vip "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ffc2/hdl/axi_vip_v1_1_vl_rfs.sv" \

vlog -work processing_system7_vip_v1_0_15 -64 -incr -mfcu  -sv -L axi_vip_v1_1_13 -L processing_system7_vip_v1_0_15 -L xilinx_vip "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl/processing_system7_vip_v1_0_vl_rfs.sv" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../bd/mlp_design/ip/mlp_design_processing_system7_0_0/sim/mlp_design_processing_system7_0_0.v" \
"../../../bd/mlp_design/ip/mlp_design_mlp_0_0/sim/mlp_design_mlp_0_0.v" \

vcom -work lib_pkg_v1_0_2 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/0513/hdl/lib_pkg_v1_0_rfs.vhd" \

vlog -work fifo_generator_v13_2_7 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/83df/simulation/fifo_generator_vlog_beh.v" \

vcom -work fifo_generator_v13_2_7 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/83df/hdl/fifo_generator_v13_2_rfs.vhd" \

vlog -work fifo_generator_v13_2_7 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/83df/hdl/fifo_generator_v13_2_rfs.v" \

vcom -work lib_fifo_v1_0_16 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/6c82/hdl/lib_fifo_v1_0_rfs.vhd" \

vcom -work lib_srl_fifo_v1_0_2 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/51ce/hdl/lib_srl_fifo_v1_0_rfs.vhd" \

vcom -work lib_cdc_v1_0_2 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ef1e/hdl/lib_cdc_v1_0_rfs.vhd" \

vcom -work axi_datamover_v5_1_29 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/2237/hdl/axi_datamover_v5_1_vh_rfs.vhd" \

vcom -work axi_sg_v4_1_15 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/751a/hdl/axi_sg_v4_1_rfs.vhd" \

vcom -work axi_dma_v7_1_28 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/70c4/hdl/axi_dma_v7_1_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/mlp_design/ip/mlp_design_axi_dma_0_0/sim/mlp_design_axi_dma_0_0.vhd" \

vcom -work proc_sys_reset_v5_0_13 -64 -93  \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/8842/hdl/proc_sys_reset_v5_0_vh_rfs.vhd" \

vcom -work xil_defaultlib -64 -93  \
"../../../bd/mlp_design/ip/mlp_design_rst_ps7_0_100M_0/sim/mlp_design_rst_ps7_0_100M_0.vhd" \

vlog -work generic_baseblocks_v2_1_0 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/b752/hdl/generic_baseblocks_v2_1_vl_rfs.v" \

vlog -work axi_register_slice_v2_1_27 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/f0b4/hdl/axi_register_slice_v2_1_vl_rfs.v" \

vlog -work axi_data_fifo_v2_1_26 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/3111/hdl/axi_data_fifo_v2_1_vl_rfs.v" \

vlog -work axi_crossbar_v2_1_28 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/c40e/hdl/axi_crossbar_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../bd/mlp_design/ip/mlp_design_xbar_0/sim/mlp_design_xbar_0.v" \

vlog -work axi_protocol_converter_v2_1_27 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/aeb3/hdl/axi_protocol_converter_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../bd/mlp_design/ip/mlp_design_auto_pc_0/sim/mlp_design_auto_pc_0.v" \

vlog -work axi_clock_converter_v2_1_26 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/b8be/hdl/axi_clock_converter_v2_1_vl_rfs.v" \

vlog -work blk_mem_gen_v8_4_5 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/25a8/simulation/blk_mem_gen_v8_4.v" \

vlog -work axi_dwidth_converter_v2_1_27 -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/4675/hdl/axi_dwidth_converter_v2_1_vl_rfs.v" \

vlog -work xil_defaultlib -64 -incr -mfcu  "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ec67/hdl" "+incdir+../../../../updated_mlp_wrapper.gen/sources_1/bd/mlp_design/ipshared/ee60/hdl" "+incdir+/home/Vieira/Xilinx/Vivado/2022.2/data/xilinx_vip/include" \
"../../../bd/mlp_design/ip/mlp_design_auto_us_0/sim/mlp_design_auto_us_0.v" \
"../../../bd/mlp_design/ip/mlp_design_auto_us_1/sim/mlp_design_auto_us_1.v" \
"../../../bd/mlp_design/ip/mlp_design_auto_pc_1/sim/mlp_design_auto_pc_1.v" \
"../../../bd/mlp_design/sim/mlp_design.v" \

vlog -work xil_defaultlib \
"glbl.v"

