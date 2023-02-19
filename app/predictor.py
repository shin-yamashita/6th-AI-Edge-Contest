
import os
#import sys
import numpy as np
import math
from pyquaternion import Quaternion
import tflite_runtime.interpreter as tflite
import matplotlib.pyplot as plt
import time
import postproc
import preproc
import multiprocessing as mp
import copy
import queue

class Predictor(object):
    delegate=False
    BNDRY = 50.0
    peak_thresh = 0.2
    bg = False
    last_key = None
    last_ego_pose = None
    last_calibration = None

    @classmethod
    def set_config(cls, delegate=False, bndry=50.0, r45=False, thresh=0.2, bg=False):
        cls.delegate = delegate
        cls.BNDRY = bndry
        cls.R45 = r45
        cls.peak_thresh = thresh
        cls.parent, cls.child = mp.Pipe()
        cls.lp = None
        cls.bev = queue.Queue()
        cls.bg = bg

    @classmethod
    def get_model(cls, model_path='./model', model='model-fp32-320.tflite'):
        """Get model method
        Args:
            model_path (str): Path to the trained model directory.

        Returns:
            bool: The return value. True for success.
        """
        heads = {
        'hm_cen': 3,        # heat map  x,y,class (150,150,3)
        'cen_offset': 2,    # center offset x,y   (150,150,2) 0~1?
#        'direction': 2,     # direction y,x?      (150,150,2) yaw = atan2(y,x)
#        'z_coor': 1,        # z (obj height)      (150,150,1)
#        'dim': 3            # obj dimention h,w,l (150,150,3)
        }

        model = os.path.join(model_path, model)
        if cls.delegate:
            delegate_path = os.path.join(model_path, "dummy_external_delegate.so")
            interpreter = tflite.Interpreter(model_path=model,
                experimental_delegates=[tflite.load_delegate(delegate_path)])
        else:
            interpreter = tflite.Interpreter(model_path=model)
        print("model :", model, " delegate" if cls.delegate else " cpu")

        interpreter.allocate_tensors()
        input_details = interpreter.get_input_details()
        output_details = interpreter.get_output_details()

        inq_param = (1.0, 0.0)
        cls.inq = False
        if input_details[0]['quantization'][0]>0.0:
            inq_param = input_details[0]['quantization']
            cls.inq = True
        in_dtype = input_details[0]['dtype']

        print("in:  ", input_details[0]['name'], "id:", input_details[0]['index'], 
                "Q:", inq_param, in_dtype, input_details[0]['shape'])
        [cls.H, cls.W] = input_details[0]['shape'][1:3]
        q_param = []
        for i, outs in enumerate(output_details):
            if outs['quantization'][0]>0.0:
                q_param.append(outs['quantization'])
            else:
                q_param.append((1.0, 0.0))
            print("out: ", outs['name'], "id:", outs['index'], "Q:", q_param[i], outs['shape'])

        cls.interpreter = interpreter
        cls.input_details = input_details
        cls.output_details = output_details

        return True

    def preproc(cls, input):
        # load sample
        lidar = np.fromfile(input['lidar_path'], dtype=np.float32).reshape((-1, 5))
        #cls.lidar_ego_pose = input['lidar_ego_pose']
        #cls.lidar_calibration = input['lidar_calibration']
        if cls.bg:
            cls.test_key = cls.last_key
            cls.last_key = input['test_key']
            cls.lidar_ego_pose = cls.last_ego_pose
            cls.lidar_calibration = cls.last_calibration
            cls.last_ego_pose = input['lidar_ego_pose']
            cls.last_calibration = input['lidar_calibration']
        else:
            cls.test_key = input['test_key']
            cls.lidar_ego_pose = input['lidar_ego_pose']
            cls.lidar_calibration = input['lidar_calibration']


        cls.t = [0,0,0,0]
        cls.t[0] = time.time()   # 0
#        cls.bev_maps = cls.preprocess(cls, lidar)
        bev = preproc.preproc(lidar, cls.W, cls.BNDRY, cls.R45, cls.bg) # uint8
        bev_map = np.expand_dims(bev, axis=0)   # add batch axis

        interpreter = cls.interpreter
        if cls.inq:
            interpreter.set_tensor(cls.input_details[0]['index'], bev_map)
        else:
            interpreter.set_tensor(cls.input_details[0]['index'], (bev_map / 255.0).astype(np.float32))

        cls.t[1] = time.time()   # 1
        return bev

    def pred_s(cls):
        cls.interpreter.invoke()
        outnp = []
        for i, outs in enumerate(cls.output_details):
            outnp.append(cls.interpreter.get_tensor(outs['index']))
#        print(outnp[0].max(), outnp[0].min(), outnp[0].shape)
#        cls.hm = cls.sigmoid(cls, outnp[0][0])
        return outnp

    def postproc(cls, outnp):
        cls.t[2] = time.time()   # 2

        det = postproc.postproc(outnp[0][0], outnp[1][0], cls.peak_thresh)

        if cls.test_key:

            tdet = {}
            classes = det[ :, -1]
            for j in range(3):
                inds = (classes == j)
                tdet[j] = np.concatenate([det[inds, 0:3]], axis=1)  # score,x,y
            cls.detections = tdet

            M_SQRT1_2 = 1 / math.sqrt(2)

            # make prediction
            list_pedestrian = []
            list_vehicle = []
            for c,det in cls.detections.items():
                for d in det:
                    #print(c, d)
                    _score, _x, _y = d #_z, _h, _w, _l, _yaw = d
                    _x, _y, _z, dist = cls.distance(cls, _x, _y, 0.0) 
                    if cls.R45:
                        x1 = (_x + _y) * M_SQRT1_2  # R45
                        y1 = (_y - _x) * M_SQRT1_2
                    else:
                        x1 = _x
                        y1 = _y
                    pred = list(cls.lidar_to_global(cls, [y1, x1, _z], cls.lidar_ego_pose, cls.lidar_calibration))   # x <=> y  
                    pred[2] = float(_score)
                    #print(pred)
                    if dist > 1.0:
                        if c == 0 and dist <= 40.0:  # pedestrian
                            list_pedestrian.append(pred)
                        elif c == 1 and dist <= 50.0 :    # vehicle
                            list_vehicle.append(pred)
                    #print("%8s : %3.0f (%5.1f %5.1f) %4.1f(m)" % (cnf.id2class[c], _score*100, pred[0], pred[1], dist))
            # make output
            # 各カテゴリーの数を50以下に制限
            list_pedestrian = list_pedestrian[:50]
            list_vehicle = list_vehicle[:50]
            prediction = {}
            if len(list_pedestrian) > 0 :
                prediction["pedestrian"] = list_pedestrian
            if len(list_vehicle) > 0 :
                prediction["vehicle"] = list_vehicle

            output = {cls.test_key: prediction}
        else:
            output = None

        cls.t[3] = time.time()   # 3
        return output

    @classmethod
    def predict(cls, input):
        """Predict method
        Args:
            input: meta data of the sample you want to make inference from (dict)
        Returns:
            dict: Inference for the given input.
        """
        bev = cls.preproc(cls, input)

        cls.bev_maps = bev
        outnp = cls.pred_s(cls)
        cls.hm = cls.sigmoid(cls, outnp[0][0])
        output = cls.postproc(cls, outnp)

        return output

    def distance(cls, x, y, z):
        DISCRETIZATION = cls.BNDRY * 2 / cls.W
        x = (x - cls.W / 2) * DISCRETIZATION
        y = (y - cls.H / 2) * DISCRETIZATION
        z = z * DISCRETIZATION
        dist = math.hypot(x, y) 
        return x, y, z, dist # x,y, distance (m)

    def sigmoid(cls, a):
        return 1 / (1 + np.exp(-a))

    def lidar_to_global(cls, points, lidar_ego_pose, lidar_calibration):
        pc = np.array(points)
        pc = np.dot(Quaternion(lidar_calibration['rotation']).rotation_matrix, pc) + np.array(lidar_calibration['translation'])
        pc = np.dot(Quaternion(lidar_ego_pose['rotation']).rotation_matrix, pc) + np.array(lidar_ego_pose['translation'])
        return pc

    @classmethod
    def get_detections(cls):
        #bev_map = (cls.bev_maps * 255).astype(np.uint8)
        hm = (np.clip(cls.hm * 255, 0,255)).astype(np.uint8)
        return cls.bev_maps, cls.detections, hm

    @classmethod
    def get_time(cls):
        tm = []
        lt = 0.0
        for t in cls.t:
            tm.append(t - lt)
            lt = t
        return np.array(tm)   # [start, pre, pred, post]

