# 6th AI Edge Contest

このリポジトリでは、[6th AI Edge Contest](https://signate.jp/competitions/732) に向けて実装したシステムのソースコードを公開する。 

## 課題

- 車両前方の画像および全方位の点群データから、3D物体検出を行うアルゴリズムを作成  
- 開発したアルゴリズムを、RISC-Vを搭載したプラットフォームに実装  

## TFlite delegate と rv32emc を用いた実装

- 今回の課題に対し、TensorFlow Lite(以下TFlite) の delegate 機構を用いた FPGA アクセラレータを開発した  
  (第5回コンテストで用いたものを out channel 4並列実行するよう修正して用いた)  
- RISC-V は rv32emc に対応する CPU core を scratch から開発した  
  (第5回コンテストで用いたものに fpu を組み込んだ。fpu は整数レジスタを用いる形式"Zfinx"とした)  
- アクセラレータの実行制御と、lidar data から BEV 画像を生成する pre 処理を１つの RISC-Vで行った   
- FPGA への実装は、アクセラレータ、RISC-V core とも SystemVerilog を用いた RTL 記述で行った  
- 推論ネットワークは Super-Fast-Accurate-3D-Object-Detection-PyTorch[^1] をベースに学習を行い、pytorch → TFlite 変換の後 8bit 量子化を行った  
- アプリケーションは TFlite の python インターフェースと python C API を用い、RISC-V での BEV 画像生成処理は C言語で開発した  

[^1]:https://github.com/maudzung/SFA3D
[^1 SFA3D](https://github.com/maudzung/SFA3D)

詳細は [doc/ ](https://shin-yamashita.github.io/6th-AI-Edge-Contest) 参照

### ./app/ [→推論実行アプリケーション](app/)  

- python で記述した推論アプリケーション。  
- Xilinx [KV260](https://japan.xilinx.com/products/som/kria/kv260-vision-starter-kit/kv260-getting-started/getting-started.html) ボード上で FPGA に delegate 実行する。
- PC 上では ハードウェア検証用 Reference model に delegate 実行する。
- Object Detection 推論ネットワークは [SFA3D](https://github.com/maudzung/SFA3D) をベースに今回の課題に合わせて学習し、int8 量子化した。  

### ./tensorflow_src/tflite_delegate/  [→TFlite delegate interface](tensorflow_src/)  
- 推論アプリから delegate API を介して C++ reference model または FPGA アクセラレータに実行委譲するインターフェース関数のソース。  
- Conv2d, depthwiseConv2d の２種の演算を delegate する。
- C++ reference model は tflite の [チャネルごとの int8 量子化](https://www.tensorflow.org/lite/performance/quantization_spec) で実装した。
- FPGA アクセラレータはチャネルごとの int8 量子化のみに対応する。  

### ./tfacc_i8/  [→FPGA sources](tfacc_i8/)  
- アクセラレータ 及び rv32emc の RTL ソース。  
- rv32emc のファームウェア  
- 論理シミュレーション環境、論理合成環境。  

## files
```
├─ app                Inference application
│ └─ infer.py
├─ tensorflow_src
│ └─ tflite_delegate    Delegate interface sources (C++)
└─ tfacc_i8             FPGA design sources
  ├─ firm               Firmware for rv32emc (C)
  │ └─ rvmon
  ├─ hdl                HDL sources
  │ ├─ acc              Accelerator sources (SystemVerilog)
  │ ├─ rv32_core        rv32emc sources (SystemVerilog)
  │ ├─ tfacc_cpu_v1_0.v Controller top design
  │ └─ tfacc_memif.sv   Data pass top design
  ├─ ip                 Xilinx ip
  ├─ sim                Logic simulation environment
  └─ kria_syn           Logic synthesis environment
```
## 推論実行結果

app / infer.py 実行結果  
320x320  BEV 画像と検出結果の heatmap  
【国立大学法人東海国立大学機構名古屋大学・一般社団法人人間機械協奏技術コンソーシアムのデータセットを利用】  
![example-anime](doc/docs/rimg/anime_ov.gif)



## References
- [第6回AIエッジコンテスト（実装コンテスト④)](https://signate.jp/competitions/732)
- [Xilinx / Kria-PYNQ](https://github.com/Xilinx/Kria-PYNQ)
- [tensorflow r2.7 sources](https://github.com/tensorflow/tensorflow/tree/r2.7) 
- [TensorFlow Lite デリゲート](https://www.tensorflow.org/lite/performance/delegates)
- [TensorFlow Lite カスタムデリゲートの実装](https://www.tensorflow.org/lite/performance/implementing_delegate#when_should_i_create_a_custom_delegate)
- [TensorFlow Lite 8ビット量子化仕様](https://www.tensorflow.org/lite/performance/quantization_spec) 

## License
- [Apache License 2.0](LICENSE)
