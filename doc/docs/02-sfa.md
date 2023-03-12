
# 推論ネットワーク

- 3D物体検出のベースネットワークは Super-Fast-Accurate-3D-Object-Detection-PyTorch[^1] (SFA3D) を選択した  
  車両全方位の LiDAR データから BEV 鳥瞰画像を生成し、fpn_resnet_18 を用いた CenterNet で物体中心座標を推論する  
- BEV 画像は 608 x 608 x 3 の ２次元画像であるが、R/G/Bに相当する画素データとして、intensity / height / density としている。  
    1.  intensity は LiDAR データの輝度である。輝度はsoftmax 関数で圧縮された最大1.0の値をとる。BEV１画素の中に複数の点が入った場合 height (z 軸) 最大の点の輝度で代表する。  
    2. height は LiDAR データの z軸(物体の高さ)であるが、BEV１画素の中に複数の点が入った場合は最大値を保持する。  
    3. density は、BEV１画素の中に入った点の数を log 圧縮した値である。  

    このような RGB ２次元画像とした BEV 画像に CenterNet を適用することで、高い精度を得ている。  

- CenterNet の出力 heatmap (152x152x3(class)) 画像はBEV画像の 1/4 解像度であり、画素の分解能が低い。
検出物体位置の分解能を上げるため、cen_offset (152x152x2(xy) heatmap １画素内の２次元オフセット値) を推論することで位置精度を出す構造である。  
- 物体のサイズ、向きを同時に推論できるが、今回の課題では物体の中心座標のみ求められたので、処理の高速化のために heatmap と cen_offset のみに絞った。  

## 課題に合わせた学習  

- 学習には提供された OperaDataset のうち、全方位でアノテーションされているデータのみ用い、shuffle した後に train 90% val 10% に分けて学習した  
- SFA3D の学習環境は、kitti dataset を前提としている。このため、OperaDataset の nuScenes format から kitti format に変換した。  
  [nuScenes devkit](https://github.com/nutonomy/nuscenes-devkit) の [export_kitty.py](https://github.com/nutonomy/nuscenes-devkit/blob/master/python-sdk/nuscenes/scripts/export_kitti.py) を今回提供されたデータに合わせて改造して用いた。  
  （自車前方の定義、アノテーションクラスなどを変更した）  

- 課題に合わせ、BEV のサイズ、自車前方の方角 を変更して学習した  
    sfa/config/kitti_config.py,  train_config.py 等を修正 :    
    BEV画素サイズ → 320x320 / 448 x 448 / 608 x 608  
    boundary 設定 → 前後左右に 50m / 42m  
    自車前方の方角 → 0° / 45°   

- 今回の課題では物体の中心座標のみ求めるので、動作速度の観点でネットワークの出力を heatmap と center offset に絞った  
  また、fpn_resnet_18 (sfa/models/fpn_resnet.py) の中の ReLU を ReLU6 に変更したところ量子化後の精度が若干改善した  

<figure>
<img src=rimg/train_val.svg width=720>
 <figcaption>図1. 学習の経過 : training loss / validation loss</figcaption></figure>


[^1]:https://github.com/maudzung/SFA3D
[^1 SFA3D](https://github.com/maudzung/SFA3D)
<div style="page-break-before:always"></div>

## pytorch → TFlite 変換 → int8 量子化
学習後の pytorch ネットワークを TFlite に変換し、8bit 量子化を行った  

- pytorch model を openvino2tensorflow[^2] で TFlite に変換し、Training 後の量子化を行って、8bit に量子化した。  
    Training 後の量子化で用いるネットワークの入力画像に training/validation で用いた BEV 画像を用いることで、量子化後の精度が向上した。  
- TFlite のネットワークを編集し、Pad+Conv2D(valid) を Conv2D(same) に置き換えた(図2)  
     pytorch → TFlite 変換で、Conv2D の仕様の不整合[^3]から pytorch:Conv2D(same) -> TFlite:Pad+Conv2D(valid) に変換されてしまう(余分な Pad 処理が発生する)  
  Conv2D の stride 設定が 1 のときは単純に Pad をバイパスし、valid を same に書き換えればよいが、stride が 2 のときに Conv2D の出力位相が合わなくなる。strideが 2 のノードは FPGA のアクセラレータの設定を修正して位相を合わせるようにした  

<figure>
<img src=rimg/torch_to_tflite_conv.svg >
 <figcaption>図2. pytorch → TFlite 変換で余分なPADが発生する問題と対処</figcaption></figure>

[^2]:https://qiita.com/PINTO/items/7a0bcaacc77bb5d6abb1
[^2 openvino2tensorflow](https://qiita.com/PINTO/items/7a0bcaacc77bb5d6abb1)

[^3]:https://stackoverflow.com/questions/52975843/comparing-conv2d-with-padding-between-tensorflow-and-pytorch
[^3 comparing-conv2d-with-padding-between-tensorflow-and-pytorch](https://stackoverflow.com/questions/52975843/comparing-conv2d-with-padding-between-tensorflow-and-pytorch)

### TFlite ネットワークの編集
TFlite のモデルを一旦 json に変換し、json を python script で編集し、再び TFlite に戻す。  
[tflite2json2tflite](https://github.com/PINTO0309/tflite2json2tflite)    


??? "TFlite model graph (320x320)"
    ![model](rimg/model_int8_edit.png)


