
# FPGA sources

FPGA に実装した accelerator / risc-v の RTL ソースである。  

Vivado/2021.2 で論理シミュレーション、論理合成を行った。 

----
## simulation 実行
```
$ cd sim  
   (テストベクタ tvec/tdump-*-i8.in を用意しておく必要あり)

$ ./export_ip_src.sh        # 1度だけ実行 ..ip/*.xcix の ip群の simulation 用　ソースを生成
                            #   .ip_user_files/ 以下に生成される
$ ./compile_tfacc_core.sh   # dpi-C compile, elaboration
$ ./run_tfacc_core.sh 0 5   # 0 番目から 5 番目までの test vector を simulation 実行   
```
結果は xsim-r.log に

----
## synthesis 実行
```
$ cd kria_syn  
$ ./build.sh  
```
生成物は、./rev/design_1_wrapper.bit  
design_1.bit に rename して用いる  

----
## rv32emc のファームウェアコンパイル

rv32emc の C プログラムコンパイルは riscv-gnu-toolchain の Xfinx 対応バージョン cross gcc を用いた。gcc バージョンは 10.2.0  
[cross gcc for Zfinx](https://shin-yamashita.github.io/6th-AI-Edge-Contest/10-cross-gcc.html)

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
├── firm
│   ├── rvmon                   rv32 firmware
│   │   ├── include
│   │   ├── lib                mini stdio etc library
│   │   ├── rv_preproc.cc      Lider->BEV preproc algorithm
│   │   └── rvmon.c            monitor program / Acc control(interrupt)
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
│   │   ├── rv_cache.sv           rv32 - axi cache
│   │   ├── tfacc_core.sv       Accelerator block top
│   │   └── u8adrgen.sv         Conv2d/dwConv2d address generator
│   ├── rv32_core               rv32emc  Controller sources (SystemVerilog)
│   │   ├── dpram.sv            insn/data dualport memory
│   │   ├── dpram_h.v
│   │   ├── rv_mem.sv
│   │   ├── rv_shm.sv           APB <-> rv32 shared memory (Acc parameter)
│   │   ├── pkg_rv_decode.sv
│   │   ├── rv_dec_insn.sv      INSN table
│   │   ├── rv_exp_cinsn.sv     C-INSN table
│   │   ├── rv32_core.sv        cpu/memory wrapper
│   │   ├── rv_core.sv          processor core
│   │   ├── rv_alu.sv           ALU
│   │   ├── rv_muldiv.sv        mul/div
│   │   ├── rv_regf.sv          register file 16x32
│   │   ├── rv_sio.sv           debug serial terminal
│   │   └── rv_sysmon.sv        sysmon for KV260 fan control
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
            :
│       ├── tdump-33-i8.in
│       └── tdump-34-i8.in
└── kria_syn                    Vivado synthesis environment
    ├── bd125M/                 PL block design
    ├── rev/                    report output dir
    ├── build.sh                build FPGA script
    ├── build.tcl  
    ├── read_hdl.tcl
    ├── read_ip.tcl
    ├── pinassign.xdc
    └── timing.xdc
```

