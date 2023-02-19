/*
 * Conv2D.h
 *
 *  Created on: 2021/12/19
 *      Author: shin
 */

#ifndef TFLITE_DELEGATE_CONV2D_H_
#define TFLITE_DELEGATE_CONV2D_H_

#include <iostream>
#include <stdio.h>
#include "tensorflow/lite/util.h"
#include "tensorflow/lite/builtin_ops.h"
#include "tensorflow/lite/context_util.h"
#include "tensorflow/lite/kernels/internal/common.h"
#include "tensorflow/lite/kernels/internal/tensor_ctypes.h"
#include "tensorflow/lite/c/c_api_internal.h"
#include "tensorflow/lite/c/builtin_op_data.h"
#include "tensorflow/lite/kernels/padding.h"
#include "tensorflow/lite/kernels/kernel_util.h"
#include "tensorflow/lite/kernels/internal/quantization_util.h"

namespace tflite{

struct OpParams {
    int32_t optype; //
    int16 pad_width;
    int16 pad_height;
    int16 stride_width;
    int16 stride_height;
    int16 dilation_width_factor;
    int16 dilation_height_factor;
    int16 depth_multiplier;
    // quantize params
    int32 input_offset;
    int32 output_offset;
    int   output_shift;
    int32_t *per_channel_multiplier;
    void  *convparam;
};

TfLiteStatus OpParamsPrepare(TfLiteContext* context,
        TfLiteTensor* input, TfLiteTensor* filter, TfLiteTensor* bias, TfLiteTensor* output,
        OpParams *opparam, int32_t optype);

char* reorder_filter(size_t *filter_size, int8_t *filter, int filH, int filW, int filC, int inC, int outC, int dwen);

TfLiteStatus Conv2DquantPerChannel(// conv / dwconv
        int n_stage,
        int dwen,
        OpParams *params,
        TfLiteTensor* input,    // int8
        TfLiteTensor* filter,   // int8
        TfLiteTensor* bias,     // int32
        TfLiteTensor* output);  // int8

void print_params(OpParams *op);


} // tflite

#endif /* TFLITE_DELEGATE_CONV2D_H_ */
