# User Generated physical constraints 

create_pblock pblock_u_rv32_core
add_cells_to_pblock [get_pblocks pblock_u_rv32_core] [get_cells -quiet [list design_1_i/tfacc_cpu_v1_0_0/inst/u_rv32_core]]
resize_pblock [get_pblocks pblock_u_rv32_core] -add {SLICE_X38Y60:SLICE_X60Y179}
resize_pblock [get_pblocks pblock_u_rv32_core] -add {DSP48E2_X10Y24:DSP48E2_X12Y71}
resize_pblock [get_pblocks pblock_u_rv32_core] -add {RAMB18_X1Y24:RAMB18_X2Y71}
resize_pblock [get_pblocks pblock_u_rv32_core] -add {RAMB36_X1Y12:RAMB36_X2Y35}
resize_pblock [get_pblocks pblock_u_rv32_core] -add {URAM288_X0Y16:URAM288_X0Y47}

#create_pblock pblock_u_u8adrgen
#add_cells_to_pblock [get_pblocks pblock_u_u8adrgen] [get_cells -quiet [list design_1_i/tfacc_memif_0/inst/u_tfacc_core/u_u8adrgen]]
#resize_pblock [get_pblocks pblock_u_u8adrgen] -add {SLICE_X0Y0:SLICE_X22Y179}
#resize_pblock [get_pblocks pblock_u_u8adrgen] -add {DSP48E2_X0Y0:DSP48E2_X5Y71}

