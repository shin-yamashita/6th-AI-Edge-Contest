
# TFlite delegate interface C++ sources

TFlite の [custom_delegate](https://www.tensorflow.org/lite/performance/implementing_delegate) に従って実装した C++ ソース。  
1. Linux PC (Ubuntu20.04) 上で Conv2d/dwConv2d の Reference model を作り、delegate の動作を確認した。  
また、論理検証用の test vector file を生成する。  
2. KV260(PYNQ Ubuntu20.04) 上で FPGA に delegate する。  

Linux PC と KV260 の共通ソース。  

## files
```
tflite_delegate/
├── BUILD            bazel
├── Conv2D.cc        Reference model
├── Conv2D.h
├── MyDelegate.cc    delegate interface source   
├── dummy_delegate.cc
├── dummy_delegate.h
├── external_delegate_adaptor.cc
├── tfacc_u8.cc      FPGA interface
└── tfacc_u8.h
```
## delegate interface source

Linux 用（Reference model） と、 KV260-pynq 用(FPGA とのインターフェース) でソースは共通。   

test vector file を出力するには、MyDelegate.cc の以下の２つの変数を設定する。  
```
static int dumpfrom = 0; // layer 0 ~ 34 まで出力する例  
static int dumpto = 34;  //  
```
推論アプリを実行し、Reference model (C++) に delegate すると、"tvec/tdump-%d-i8.in" というファイル名で Conv パラメータ + input/filter/bias/output の Tensor データを出力する。tvec/* を論理シミュレーション環境にコピーし、一致検証用に用いる。


## Build TensorFlow Lite Python Wheel Package


Google は、FlatBuffer に変換した推論グラフを高速に実行する軽量の [tflite_runtime](https://www.tensorflow.org/lite/guide/python) を提供している。  
```tflite_runtime-2.8.0-cp38-cp38-linux_x86_64.whl``` 等 wheel ファイルが入手できる場合、pip でインストールする。  
または、tensorflow のソースからここに述べる方法で build install する。  

1. **環境設定**  

   https://www.tensorflow.org/lite/guide/build_cmake_pip  を参照  
   python3 version 3.8 で検証  
   ```$ pip3 install wheel```  

   **tensorflow r2.7 ソースをダウンロード、 ../tensorflow_src に配置する。**  
   ```
   $ cd ../tensorflow_src/
   $ git clone -b r2.7 https://github.com/tensorflow/tensorflow.git  ../tensorflow_src
   ```

2. **build / install**  
   ```
   $ pip install pybind11  
   $ cd ../tensorflow_src  
   ($ export BUILD_NUM_JOBS=1  KV260 では cpu リソース不足のため job を制限。PCで aarch64 クロスコンパイルするのが良い)  
   $ tensorflow/lite/tools/pip_package/build_pip_package_with_cmake.sh native  
   ==> tensorflow/lite/tools/pip_package/gen/tflite_pip/python3/dist/tflite_runtime-2.8.0-cp38-cp38-linux_x86_64.whl  

   $ pip install tensorflow/lite/tools/pip_package/gen/tflite_pip/python3/dist/tflite_runtime-2.8.0-cp38-cp38-linux_x86_64.whl  
   ```

## **build delegate interface library**

build には bazel を用いており、Linux PC と KV260 で build 手順は同じ。  

1. **環境設定**

   **tensorflow r2.7 ソースをダウンロード、 ../tensorflow_src に配置する。**  
   ```
   $ cd ../tensorflow_src/
   $ git clone -b r2.7 https://github.com/tensorflow/tensorflow.git  ../tensorflow_src
   ```

   tensorflow r2.7 のソースツリーの top に tflite_delegate/* が配置される。  
   ```bash
   $ ls ../tensorflow_src/tflite_delegate/  
   BUILD  Conv2D.cc  Conv2D.h  MyDelegate.cc ...
   ```

   **bazel の導入**  
   https://bazel.build/install/bazelisk?hl=ja を参照  
   https://github.com/bazelbuild/bazelisk/releases  から bazelisk binary を download  
   - Linux PC : bazelisk-linux-amd64  
   - KV260 :  bazelisk-linux-arm64  
   任意の実行パスに bazel として配置する。  
   ```bash
   ex: 
   $ cp bazelisk-linux-amd64 ~/bin/
   $ chmod +x ~/bin/bazelisk-linux-amd64
   $ ln -s ~/bin/bazelisk-linux-amd64 ~/bin/bazel
   ```

2. **delegate interface の build**  
   tensorflow_src の下で以下のコマンドを実行する  
   ``` bash
   $ cd ../tensorflow_src  
   $ bazel build -c opt tflite_delegate/dummy_external_delegate.so  --define `uname -m`=1
   ```

   ```--define `uname -m`=1```  によって LinuxPC(x86_64) と KV260(aarch64) を切り替えでいる。C++ ソースでは、 `#ifdef ULTRA96` で切り替える。    

   KV260 では cpu リソース不足のため、`--local_ram_resources=HOST_RAM*.5` などのオプションをつけたほうが良い。  

   bazel で build すると、自動的に bazel-bin などの symbolic link ができており、  

   bazel-bin/tflite_delegate/dummy_external_delegate.so が python の delegate interface になる  

   生成物: **dummy_external_delegate.so**   
   tflite python API から呼び出す。 tflite_runtime.Interpreter に link して用いる。  

## python API

新たに作成した delegate インターフェースをダイナミックリンクライブラリ(dummy_external_delegate\.so)として tflite_runtime にリンクすることで実行の delegate が行われる。  
tflite_runtime の python インターフェースでは interpreter のインスタンス時に dummy_external_delegate\.so を指定してリンクするだけである。

[^6]:https://www.tensorflow.org/lite/guide/python

```python
import tflite_runtime.interpreter as tflite
# Instantiate interpreter
interpreter = tflite.Interpreter(model_path=model, 
      experimental_delegates=[tflite.load_delegate(
        　　　　　　　'{path-to}/dummy_external_delegate.so.1')] )      
interpreter.allocate_tensors()
# Get input and output tensors.
input_details  = interpreter.get_input_details()
output_details = interpreter.get_output_details()
  :
# preproc
bev_image = preproc.preproc(frame)  # lidar data -> BEV image
# set image
interpreter.set_tensor(input_details[0]['index'], np.uint8(bev_image)) 
# Invoke
interpreter.invoke()
# Output inference result
heatmap = interpreter.get_tensor(output_details[0]['index'])[0]
cen_offset = interpreter.get_tensor(output_details[1]['index'])[0]
# postproc
det = postproc.postproc(heatmap, cen_offset)
  :
```

