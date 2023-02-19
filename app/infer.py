#!/usr/bin/env python3
#
# 6th AI-Edge-Contest
# 
# reference: https://github.com/maudzung/SFA3D

import sys
import json
import argparse
import os
import cv2
import time
import math
import numpy as np
import select
import tty
import termios
from predictor import Predictor

id2class = {
    0:  'Pedestrian', 
    1:  'Car', 
    2:  '--', 
    }

def iskbhit():
    return select.select([sys.stdin], [], [], 0) == ([sys.stdin], [], [])

time_average = np.array([0.0,0.0,0.0,0.0])
naverage = 0

def time_measure(tm):
    global time_average, naverage
    time_average += tm
    naverage += 1
    tm *= 1e3
    print("pre: %5.1f pred: %5.1f post: %5.1f ms" % (tm[1], tm[2], tm[3]))

model_size = {'S': 320, 'M': 448, 'L': 608}

def main():
    # parse the arguments    
    parser = argparse.ArgumentParser(formatter_class=argparse.ArgumentDefaultsHelpFormatter)
    parser.add_argument('--test-meta-path',     default = '../data/meta/meta_data.json',help = "test meta_data path")
    parser.add_argument('--test-data-dir',      default = '../data/train/3d_labels',    help = "lider data directory")
    parser.add_argument('--model-path',         default = './model',            help = "model directory")
    parser.add_argument('--result-path',        default = './result',           help = "result json directory")
    parser.add_argument('--th', type=float,     default = 0.2,                  help = "score threshold")
    parser.add_argument('--view',               action='store_true',            help = "view BEV and heatmap")
    parser.add_argument('--delegate', '-d',     action='store_true',            help = "delegate or cpu")
    parser.add_argument('--fp32',  '-f',        action='store_true',            help = "use fp32 network")
    parser.add_argument('--rot45', '-r',        action='store_true',            help = "rotate BEV 45 degree")
    parser.add_argument('--fg', '-fg',          action='store_true',            help = "preproc forground")
    parser.add_argument('--size',  '-s', choices=['S','M','L'], default = 'S',  help = "BEV size S:320/M:448/L:608")
    args = parser.parse_args()

    test_meta_path = os.path.abspath(args.test_meta_path)
    result_path = os.path.abspath(args.result_path)
    test_data_dir = os.path.abspath(args.test_data_dir)
    result_path = os.path.join(result_path, f"result-{'fp32' if args.fp32 else 'int8'}.json")

    W = model_size[args.size]
    R45 = args.rot45
    BNDRY = 42.0 if R45 else 50.0   # BEV boundary -BNDRY to BNDRY 
    ppbg = not args.fg  # pre-proc background enable

    if os.uname()[-1] == 'aarch64':
        int8 = 'int8e'  # edited model (remove pad)
        delegate = not args.delegate
    else:
        int8 = 'int8'
        delegate = args.delegate
        ppbg = False

    if args.fp32:
            delegate = False

    # model file name ex: "model-int8e-320-R.tflite"
    model = f"model-{'fp32' if args.fp32 else int8}-{W}{'-R' if args.rot45 else ''}.tflite"

    Predictor.set_config(delegate=delegate, bndry=BNDRY, r45=R45, thresh=args.th, bg=ppbg)

    print(f'Loading the model {model}...', end = '\r')
    model_flag = Predictor.get_model(args.model_path, model)
    if model_flag:
        print('Loaded the model.   ')
    else:
        print('Could not load the model.')
        return None

    with open(test_meta_path) as f:
        test_meta = json.load(f)
    # run all and save the result
    result = {}
    wait = 0
    tNp = 0
    tNc = 0
    for scene_id, frames in test_meta.items():
        print(scene_id)
        for i, frame in enumerate(frames):
            #frame['cam_path'] = os.path.join(test_data_dir, frame['cam_path'])
            frame['lidar_path'] = os.path.join(test_data_dir, frame['lidar_path'])

            output = Predictor.predict(frame)

            if output: 
                result.update(output)
                time_measure(Predictor.get_time())

            if(iskbhit()):
                c = sys.stdin.read(1) # non blocking keyboard input
                if(c == '\x1b'):  # ESC : quit
                    return None

            if output and args.view:
                bev_map, detections, hm = Predictor.get_detections()
                #bev_map = cv2.resize(bev_map, (W, W))
                hm = cv2.resize(hm, (W, W), interpolation=cv2.INTER_NEAREST)
                Np = 0
                Nc = 0
                Ncl = 0
                H = W/2
                for c,det in detections.items():
                    for d in det:
                        #print(c, d)
                        _score, _x, _y = d  #, _z, _h, _w, _l, _yaw = d
                        if c < 2:
                            print("%s %d %8s : %3.0f (%5.1f %5.1f)" % (scene_id, i, id2class[c], _score*100, _x-H, _y-H))
                        dist = math.hypot(_x-H, _y-H) * BNDRY / H
                        color = (130,130,130)
                        if c == 0: 
                            Np += 1
                            if dist <= 40.0: tNp += 1
                            color = (255,0,255)
                        elif c == 1: 
                            Nc += 1
                            if dist <= 50.0: tNc += 1
                            color = (255,255,0)
                        cv2.drawMarker(bev_map, (int(_x), int(_y)), color, markerType=cv2.MARKER_CROSS, markerSize=20)
                        #cv2.drawMarker(hm, (int(_x), int(_y)), color, markerType=cv2.MARKER_CROSS, markerSize=5)
                bev_map = cv2.rotate(bev_map, cv2.ROTATE_180)
                hm = cv2.rotate(hm, cv2.ROTATE_180)
                cv2.putText(bev_map, text='%s %d P:%d C:%d'%(scene_id, i, Np, Nc), org=(10, 30),
                    fontFace=cv2.FONT_HERSHEY_SIMPLEX, fontScale=0.5, color=(0, 255, 0), thickness=1, lineType=cv2.LINE_4)
                cv2.circle(bev_map, (int(H),int(H)), int(H*40/BNDRY), (150,0,150))
                cv2.circle(bev_map, (int(H),int(H)), int(H*50/BNDRY), (150,150,0))
                cv2.imshow('bev map', cv2.hconcat([bev_map, hm[:,:,::-1]]))
                key = cv2.waitKey(wait) & 0xff
                if key == 27:
                    break
                elif key == ord('p'):
                    if wait == 0: wait = 10
                    else: wait = 0
                #elif key == ord('c'):
                #    cv2.imwrite("capture.png", cv2.hconcat([bev_map, hm[:,:,::-1]]))
        else:
            continue
        break

    if args.view:
        print(f" Detected object  Car : {tNc}  Pedestrian : {tNp}")

    with open(result_path, 'w', encoding='utf-8') as f:
        json.dump(result, f)
        print(f" Predicted result saved : {result_path}")


if __name__ == '__main__':
    tty_settings = termios.tcgetattr(sys.stdin)
    try:
        tty.setcbreak(sys.stdin.fileno())
        main()       
        tm = (time_average / naverage) * 1e3
        print("time average  pre: %5.1f pred: %5.1f post: %5.1f ms" % (tm[1], tm[2], tm[3]))
    finally:
        termios.tcsetattr(sys.stdin, termios.TCSADRAIN, tty_settings)