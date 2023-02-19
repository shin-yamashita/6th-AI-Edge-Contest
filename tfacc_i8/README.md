
# FPGA sources

FPGA に実装した accelerator の RTL ソースである。  

Vivado/2020.2 Webpack で論理シミュレーション、論理合成を行った。 

----
## simulation 実行
```
$ cd sim  
$ ./export_ip_src.sh        # 1度だけ実行 ..ip/*.xcix の ip群の simulation 用　ソースを生成
                            #   .ip_user_files/ 以下に生成される
$ ./compile_tfacc_core.sh   # dpi-C compile, elaboration
$ ./run_tfacc_core.sh 0 5   # 0 番目から 5 番目までの test vector を simulation 実行   
```
結果は xsim-r.log に

----
## synthesis 実行
```
$ cd syn  
$ ./build.sh  
```
生成物は、./rev/design_1_wrapper.bit  
design_1.bit に rename して用いる  
```
FPGA_DATA = ../../infer/fpga-data/
        cp rev/design_1_wrapper.bit $(FPGA_DATA)/design_1.bit
        cp ../bd/design_1/hw_handoff/design_1.hwh $(FPGA_DATA)/
```

----
## rv32emc のファームウェアコンパイル

rv32emc の C プログラムコンパイルは riscv-gnu-toolchain の cross gcc を用いた。  
gcc バージョンは 9.2.0 (gcc ver 11 では実行時に異常な動作がある、未解決)
```
*** cross gcc の build / install ***
$ sudo apt install gawk texinfo bison flex  
$ git clone --recursive https://github.com/riscv/riscv-gnu-toolchain
$ cd riscv-gnu-toolchain
$ ./configure --prefix=/opt/rv32e --disable-linux --with-arch=rv32emac --with-abi=ilp32e
$ make newlib
$ make install   # /opt/rv32e/　に cross gcc をインストール
```
ファームウエアのコンパイル  
```
$ cd firm/rvmon
$ make rvmon.mot   # FPGA の rv32emc core にロードするバイナリを生成
```
rv32emc に関しては、別のリポジトリ https://github.com/shin-yamashita/rv32emc にコアの開発のために作成した ISS やテストプログラムを載せている。  


----
## files
```
tfacc_i8/
├── README.md
├── bd                           PL block design (user clock = 125MHz)
├── doc
├── firm
│   ├── rvmon                   rv32 firmware
│   │   ├── include
│   │   ├── lib                mini stdio etc library
│   │   ├── pre_data.c         tracking algorithm
│   │   └── rvmon.c            monitor program
│   └── term/                   debug serial terminal
├── hdl                         FPGA RTL sources
│   ├── acc                     Accelerator sources (SystemVerilog)
│   │   ├── i8mac.sv            int8 MAC
│   │   ├── input_arb.sv        input access arbiter
│   │   ├── input_cache.sv
│   │   ├── logic_types.svh
│   │   ├── output_arb.sv       output access arbiter
│   │   ├── output_cache.sv
│   │   ├── rd_cache_nk.sv      filter/bias/quant buffer
│   │   ├── rv_axi_port.sv      rv32 axi access port
│   │   ├── tfacc_core.sv       Accelerator block top
│   │   └── u8adrgen.sv         Conv2d/dwConv2d address generator
│   ├── rv32_core               rv32emc  Controller sources (SystemVerilog)
│   │   ├── dpram.sv            insn/data dualport memory
│   │   ├── dpram_h.v
│   │   ├── rv_mem.sv
│   │   ├── pkg_rv_decode.sv
│   │   ├── rv_dec_insn.sv      INSN table
│   │   ├── rv_exp_cinsn.sv     C-INSN table
│   │   ├── rv32_core.sv        cpu/memory wrapper
│   │   ├── rv_core.sv          processor core
│   │   ├── rv_alu.sv           ALU
│   │   ├── rv_muldiv.sv        mul/div
│   │   ├── rv_regf.sv          register file 16x32
│   │   ├── rv_sio.sv           debug serial terminal
│   │   └── rv_types.svh
│   ├── tfacc_cpu_v1_0.v        Controller top design      
│   └── tfacc_memif.sv          Data pass top design
├── ip/                         FPGA ip (axi/bram)
├── sim/                        Vivado simulation environment
│ ├── compile_tfacc_core.sh     Elaborate testbench  
│ ├── run_tfacc_core.sh         Execute logic simulation
│ ├── xsim_tfacc_core.sh        Execute logic simulation (GUI)
│ ├── tb_tfacc_core.prj
│ ├── tb_tfacc_core.sv          Testbench
│ ├── axi_slave_bfm.sv          AXI bus functiol model with dpi-c interface
│ ├── c_main.c                  dpi-c source
│ └── tvec/                      test vectors
│       ├── tdump-0-i8.in

│       ├── tdump-70-i8.in
│       └── tdump-71-i8.in
└── syn                         Vivado synthesis environment
    ├── rev/                    report output dir
    ├── build.sh                build FPGA script
    ├── build.tcl  
    ├── design_1_bd.tcl
    ├── dont_touch.xdc
    ├── read_hdl.tcl
    ├── read_ip.tcl
    ├── tfacc_pin.xdc
    └── timing.xdc
```

