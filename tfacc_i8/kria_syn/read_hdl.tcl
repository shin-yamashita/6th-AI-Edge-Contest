
# compilation unit 1
read_verilog -library xil_defaultlib -sv {
  ../hdl/acc/logic_types.svh
  ../hdl/acc/u8adrgen.sv
  ../hdl/acc/i8mac.sv
  ../hdl/acc/rd_cache_nk.sv
  ../hdl/acc/tfacc_core.sv
  ../hdl/acc/input_cache.sv
  ../hdl/acc/input_arb.sv
  ../hdl/acc/output_cache.sv
  ../hdl/acc/output_arb.sv
  ../hdl/acc/rv_axi_port.sv
  ../hdl/acc/rv_cache.sv
  ../hdl/acc/dpram10m.sv
  ../hdl/acc/adrtag.sv
  ../hdl/tfacc_memif.sv
}

# compilation unit 2
read_verilog -library xil_defaultlib -sv {
  ../hdl/rv32_core/logic_types.svh
  ../hdl/rv32_core/pkg_rv_decode.sv
  ../hdl/tfacc_cpu_v1_0.v
  ../hdl/rv32_core/dpram_h.v  
  ../hdl/rv32_core/rv_exp_cinsn.sv
  ../hdl/rv32_core/rv_dec_insn.sv
  ../hdl/rv32_core/dpram.sv
  ../hdl/rv32_core/rv32_core.sv
  ../hdl/rv32_core/rv_alu.sv
  ../hdl/rv32_core/rv_core.sv
  ../hdl/rv32_core/rv_fpu.sv
  ../hdl/rv32_core/rv_mem.sv
  ../hdl/rv32_core/rv_shm.sv
  ../hdl/rv32_core/rv_muldiv.sv
  ../hdl/rv32_core/rv_regf.sv
  ../hdl/rv32_core/rv_sio.sv
  ../hdl/rv32_core/rv_sysmon.sv
}

set_property file_type "Verilog Header" [get_files ../hdl/acc/logic_types.svh]
set_property file_type "Verilog Header" [get_files ../hdl/rv32_core/logic_types.svh]
#set_property is_global_include true [get_files ../hdl/acc/logic_types.svh]
