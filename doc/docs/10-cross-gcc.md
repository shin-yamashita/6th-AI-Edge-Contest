
# Zfinx 対応 cross gcc 

6th AI Edge Contest の課題で用いた RISC-V CPU には fpu を搭載したが、ハードウェア規模を抑えるために fp レジスタを設けず、整数レジスタを用いる [Zfinx](https://wiki.riscv.org/display/HOME/Zfinx+TG) 仕様準拠とした。  
ただし、fmadd/fmsub 命令は実装しなかった。fma 命令は 3オペランドであり、改修規模が大きくなるためである。  
'Zfinx' に対応した cross-gcc は以下の場所で公開されているが、fma 命令の発生を抑止する `-mno_fmul_add` のようなコンパイルオプションは risc-v port には無いようなので、fma 命令を発生しないようにする patch を作って対応することにした。  

[cross-gcc for Zfinx](https://github.com/pz9115/riscv-gcc/wiki/How-to-regression-test)


## cross-gcc Zfinx build 手順 

1. source tree のセットアップ  

    ```sh
    $ cd {path-to}/riscv-zfinx  

    $ git clone https://github.com/riscv/riscv-gnu-toolchain
    $ cd riscv-gnu-toolchain
    $ git submodule update --init --recursive
    $ cd ..
    $ cp riscv-gnu-toolchain zfinx -r

    $ sh setup-zfinx.sh  
    $ cd zfinx  
    ```

    setup-zfinx.sh  
    ```
    #!/bin/sh
    cd zfinx

    cd riscv-gcc
    git remote add zfinx https://github.com/pz9115/riscv-gcc.git
    git fetch zfinx
    git checkout zfinx/riscv-gcc-10.2.0-zfinx
    cd ../riscv-binutils
    git remote add zfinx https://github.com/pz9115/riscv-binutils-gdb.git
    git fetch zfinx
    git checkout zfinx/riscv-binutils-2.35-zfinx
    #cd ../qemu
    #git remote add plct-qemu https://github.com/isrc-cas/plct-qemu.git
    #git fetch plct-qemu
    #git checkout plct-qemu/plct-zfinx-dev
    #git reset --hard d73c46e4a84e47ffc61b8bf7c378b1383e7316b5
    cd ..
    ```

2. build install (multi lib)  

    ```sh
    $ ./configure --prefix=/opt/rv32e/ --disable-linux --with-arch=rv32emczfinx --with-abi=ilp32e \
    --with-multilib-generator="rv32emczfinx-ilp32e--;rv32emzfinx-ilp32e--;rv32emc-ilp32e--;rv32em-ilp32e--"
    $ make -j8 newlib
    ```
    /opt/rv32e/ にインストールされる。  
    multilib 指定により、rv32emczfinx, rv32emzfinx, rv32emc, rv32em の各設定に対応した library がインストールされる。  




## fma 命令を発生させない patch 

gcc の各種マシンへの移植コードは、ソースツリー zfinx/riscv-gcc/gcc/config/ にまとまっている。risc-v は zfinx/riscv-gcc/gcc/config/riscv/ である。   
移植コードの中で、特に最終的なアセンプラ命令の生成条件が記述されているのは、zfinx/riscv-gcc/gcc/config/riscv/riscv.md (Machine description) ファイルであり、この中に記述されている fmadd/fmsub 命令の生成条件を disable することで、fmadd/fmsub を発生しないコンパイラにすることができる。  
以下、今回の修正箇所である。アセンブラ命令 'fmadd' などを生成する条件が記述されており、disable したい命令の生成条件式に "&& 0" を加えたのみである。  

??? "fma 命令 disable patch"

    ```
    diff --git a/gcc/config/riscv/riscv.md b/gcc/config/riscv/riscv.md
    index 99cd6c64397..4db2e18346c 100644
    --- a/gcc/config/riscv/riscv.md
    +++ b/gcc/config/riscv/riscv.md
    @@ -817,7 +817,7 @@
    (define_insn "sqrt<mode>2"
    [(set (match_operand:ANYF            0 "register_operand" "=f")
        (sqrt:ANYF (match_operand:ANYF 1 "register_operand" " f")))]
    -  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && TARGET_FDIV"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && TARGET_FDIV && 0"
    {
        return "fsqrt.<fmt>\t%0,%1";
    }
    @@ -832,7 +832,7 @@
        (fma:ANYF (match_operand:ANYF 1 "register_operand" " f")
            (match_operand:ANYF 2 "register_operand" " f")
            (match_operand:ANYF 3 "register_operand" " f")))]
    -  "TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && 0"
    "fmadd.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    @@ -843,7 +843,7 @@
        (fma:ANYF (match_operand:ANYF           1 "register_operand" " f")
            (match_operand:ANYF           2 "register_operand" " f")
            (neg:ANYF (match_operand:ANYF 3 "register_operand" " f"))))]
    -  "TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && 0"
    "fmsub.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    @@ -855,7 +855,7 @@
            (neg:ANYF (match_operand:ANYF 1 "register_operand" " f"))
            (match_operand:ANYF           2 "register_operand" " f")
            (neg:ANYF (match_operand:ANYF 3 "register_operand" " f"))))]
    -  "TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && 0"
    "fnmadd.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    @@ -867,7 +867,7 @@
            (neg:ANYF (match_operand:ANYF 1 "register_operand" " f"))
            (match_operand:ANYF           2 "register_operand" " f")
            (match_operand:ANYF           3 "register_operand" " f")))]
    -  "TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && 0"
    "fnmsub.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    @@ -880,7 +880,7 @@
            (neg:ANYF (match_operand:ANYF 1 "register_operand" " f"))
            (match_operand:ANYF           2 "register_operand" " f")
            (neg:ANYF (match_operand:ANYF 3 "register_operand" " f")))))]
    -  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode)"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode) && 0"
    "fmadd.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    @@ -893,7 +893,7 @@
            (neg:ANYF (match_operand:ANYF 1 "register_operand" " f"))
            (match_operand:ANYF           2 "register_operand" " f")
            (match_operand:ANYF           3 "register_operand" " f"))))]
    -  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode)"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode) && 0"
    "fmsub.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    @@ -906,7 +906,7 @@
            (match_operand:ANYF 1 "register_operand" " f")
            (match_operand:ANYF 2 "register_operand" " f")
            (match_operand:ANYF 3 "register_operand" " f"))))]
    -  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode)"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode) && 0"
    "fnmadd.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    @@ -919,7 +919,7 @@
            (match_operand:ANYF           1 "register_operand" " f")
            (match_operand:ANYF           2 "register_operand" " f")
            (neg:ANYF (match_operand:ANYF 3 "register_operand" " f")))))]
    -  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode)"
    +  "(TARGET_HARD_FLOAT || TARGET_ZFINX || TARGET_ZDINX) && !HONOR_SIGNED_ZEROS (<MODE>mode) && 0"
    "fnmsub.<fmt>\t%0,%1,%2,%3"
    [(set_attr "type" "fmadd")
        (set_attr "mode" "<UNITMODE>")])
    ```

