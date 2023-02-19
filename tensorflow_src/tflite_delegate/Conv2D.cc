/*
 */
#include "Conv2D.h"
#include "tfacc_u8.h"

namespace tflite {

//--- for tfacc_u8 debug ----
static int accmax = 0;
static int n_stage = 0;
static int dumpfrom = 72;    // 72
static int dumpto = 34;
static FILE *dfp1 = NULL;

// int32 quantized_multiplier ....  [31:8] multiplier,  [7:0] shift

inline int32 _MultiplyByQuantizedMultiplier(int32 x, int32 quantized_multiplier) {
    int8  shift = (quantized_multiplier & 0xff);	// right shift only
    int32 xx = ((int64_t)x * ((quantized_multiplier)>>15)) >> 16;
    //    int32 dp = (1 << (-shift-1));
    int32 mask = (1 << shift) - 1;
    int32 th = (mask >> 1) + (x < 0);
    int32 rem = xx & mask;
//    if(dbg) printf("acc:%d th:%x rem:%x accm:%x\n", x, th, rem, (xx >> shift) + (rem > th));
    return (xx >> shift) + (rem > th);
}

inline int _Offset(const RuntimeShape& shape, int i0, int i1, int i2, int i3) {
    const int* dims_data = reinterpret_cast<const int*>(shape.DimsDataUpTo5D());
    return ((i0 * dims_data[1] + i1) * dims_data[2] + i2) * dims_data[3] + i3;
}

void print_params(OpParams *op)
{
    printf("pad:%d,%d str:%d,%d dil:%d,%d dpth:%d iofs:%d oofs:%d mul:%d shf:%d\n",
            op->pad_width, op->pad_height, op->stride_width, op->stride_height,
            op->dilation_width_factor, op->dilation_height_factor,
            op->depth_multiplier, op->input_offset, op->output_offset,
            op->per_channel_multiplier[0], (int8)(op->per_channel_multiplier[0]&0xff)//, op->per_channel_shift[0]
    );
}

void _QuantizeMultiplier(double double_multiplier, int32_t* quantized_multiplier, int* shift) {
    if (double_multiplier == 0.) {
        *quantized_multiplier = 0;
        *shift = 0;
        return;
    }
    const double q = std::frexp(double_multiplier, shift);
    auto q_fixed = static_cast<int64_t>(TfLiteRound(q * (1LL << 31)));
    TFLITE_CHECK(q_fixed <= (1LL << 31));
    if (q_fixed == (1LL << 31)) {
        q_fixed /= 2;
        ++*shift;
    }
    if (*shift < -31) {
        *shift = 0;
        q_fixed = 0;
    }
    *quantized_multiplier = static_cast<int32_t>(q_fixed);
}

// Per-axis & per-tensor
TfLiteStatus PopulateConvQuantParams(	// return packed mult|shift
        TfLiteContext* context, const TfLiteTensor* input,
        const TfLiteTensor* filter, const TfLiteTensor* bias, TfLiteTensor* output,
        int32_t* per_channel_multiplier, int num_channels) {
    // Check data type.
    const auto* affine_quantization =
            reinterpret_cast<TfLiteAffineQuantization*>(filter->quantization.params);
    // Populate multiplier and shift using affine quantization.
    const float input_scale = input->params.scale;
    const float output_scale = output->params.scale;
    const float* filter_scales = affine_quantization->scale->data;
    for (int i = 0; i < num_channels; ++i) {
        const double effective_output_scale = input_scale * filter_scales[i] / output_scale;
        int32_t significand;
        int channel_shift;
        _QuantizeMultiplier(effective_output_scale, &significand, &channel_shift);
        per_channel_multiplier[i] = (significand & ~0xff) | (-channel_shift & 0xff);	// 31~8:mult 7~0:shift
    }
    return kTfLiteOk;
}

// It's not guaranteed that padding is symmetric. It's important to keep
// offset for algorithms need all paddings.
inline int _ComputePaddingWithOffset(int stride, int dilation_rate, int in_size, int filter_size, int out_size){
    int effective_filter_size = (filter_size - 1) * dilation_rate + 1;
    int total_padding = ((out_size - 1) * stride + effective_filter_size - in_size);
    total_padding = total_padding > 0 ? total_padding : 0;
    return total_padding / 2;
}

char* reorder_filter(size_t *filter_size, int8_t *filter, int filH, int filW, int filC, int inC, int outC, int dwen)
{
//-- channel parallel test
    int depthmul = 1;
    int ch1C = dwen ? inC : outC;
    int ch2C = dwen ? 1 : inC;
    int finc = dwen ? filC : 1;
    int fil_size = filH * filW * filC;
    int filp_inc = filH * filW * ch2C;
    int Noutc = ch1C*depthmul;
    if(Noutc % 4) {
        //fprintf(stderr, "Noutc (%d) is not a multiple of 4\n", Noutc);
        Noutc = (Noutc + 3) & ~3;
    }
    int filter_ttl = filp_inc * Noutc;
    uint32_t* filpdata = (uint32_t*)cma_malloc(filter_ttl);
    int8_t*  filpdatapt = (int8_t*)filpdata;
    // re-order filter access sequence
//    fprintf(stderr, "filp_inc:%d filter_ttl:%d (+%d) ch1C*depthmul:%d Noutc:%d\n", filp_inc, filter_ttl, filter_ttl-filter->bytes, ch1C*depthmul, Noutc);
    for (int out_c = 0; out_c < ch1C*depthmul; out_c++) {
    //for (int out_c = 0; out_c < Noutc; out_c++) {  
        int ch = out_c & 0x3;
        const int ch1 = out_c / depthmul;
        const int8_t* filpt = dwen ? &filter[out_c] : &filter[fil_size * ch1];
        for (int ix = 0; ix < filH*filW*ch2C; ++ix) {
            int8_t fil_d = *filpt;
            filpt += finc;
            filpdatapt[ix * 4 + ch] = fil_d;
        }
        if(ch == 3)
            filpdatapt += filp_inc * 4;
    }
    *filter_size = filter_ttl;
    return (char*)filpdata;
//    filter = (uint8_t*)realloc(filter, filter_ttl);
//    memcpy(filter, filpdata, filter_ttl);
//    filter_size = filter_ttl;
}


TfLiteStatus OpParamsPrepare(TfLiteContext* context,
        TfLiteTensor* input, TfLiteTensor* filter, TfLiteTensor* bias, TfLiteTensor* output,
        OpParams *opparam, int32_t optype)
{
    int out_width  = output->dims->data[2];
    int out_height = output->dims->data[1];
    int width  = input->dims->data[2];
    int height = input->dims->data[1];
    int filter_width  = filter->dims->data[2];
    int filter_height = filter->dims->data[1];
    void *convparam = opparam->convparam;
    //    int offset = 0;
    opparam->optype = optype;
    opparam->input_offset = -input->params.zero_point;
    opparam->output_offset = output->params.zero_point;

    if(optype == kTfLiteBuiltinConv2d){
        auto* params = reinterpret_cast<TfLiteConvParams*>(convparam);
        opparam->pad_height =
                _ComputePaddingWithOffset(params->stride_height, params->dilation_height_factor, height,
                        filter_height, out_height);	//, &offset);
        opparam->pad_width =
                _ComputePaddingWithOffset(params->stride_width, params->dilation_width_factor, width,
                        filter_width, out_width);	//, &offset);
        opparam->stride_width = params->stride_width;
        opparam->stride_height = params->stride_height;
        opparam->dilation_width_factor = params->dilation_width_factor;
        opparam->dilation_height_factor = params->dilation_height_factor;
        opparam->depth_multiplier = 1;

    }else if(optype == kTfLiteBuiltinDepthwiseConv2d){
        auto* params = reinterpret_cast<TfLiteDepthwiseConvParams*>(convparam);
        opparam->pad_height =
                _ComputePaddingWithOffset(params->stride_height, params->dilation_height_factor,
                        height, filter_height, out_height);	//, &offset);
        opparam->pad_width =
                _ComputePaddingWithOffset(params->stride_width, params->dilation_width_factor,
                        width, filter_width, out_width);	//, &offset);
        opparam->stride_width = params->stride_width;
        opparam->stride_height = params->stride_height;
        opparam->dilation_width_factor = params->dilation_width_factor;
        opparam->dilation_height_factor = params->dilation_height_factor;
        opparam->depth_multiplier = params->depth_multiplier;
    }else{  // error
        TF_LITE_ENSURE_STATUS(kTfLiteError);
    }
    PopulateConvQuantParams(context, input, filter, bias, output,
            opparam->per_channel_multiplier,	// opparam->per_channel_shift,
            output->dims->data[3]);

    return kTfLiteOk;
}

void short_dump(int nst, const int8* in, const int8* fil, const int32* b, int32_t* q, int8* o){
    int i;
    printf("%2d i:", nst);
    for(i = 0; i < 16; i++) printf(" %3d", in[i]);
    printf("\n   f:");
    for(i = 0; i < 16; i++) printf(" %3d", fil[i]);
    printf("\n   b:");
    for(i = 0; i < 8; i++) printf(" %3d", b[i]);
    printf("\n   q:");
    for(i = 0; i < 8; i++) printf(" %4x", q[i]);
    printf("\n   o:");
    for(i = 0; i < 16; i++) printf(" %3d", o[i]);
    printf("\n");

}
int8 limit_i8(int32 x){
    return x < -128 ? -128 : (x >= 127 ? 127 : x);
}

TfLiteStatus Conv2DquantPerChannel(// conv / dwconv
        int nix,
        int dwen,
        OpParams *params,
        TfLiteTensor* input,    // int8
        TfLiteTensor* filter,   // int8
        TfLiteTensor* bias,     // int32
        TfLiteTensor* output){  // int8

    const RuntimeShape& input_shape = GetTensorShape(input);
    const int8* input_data = GetTensorData<int8>(input);
    const RuntimeShape& filter_shape = GetTensorShape(filter);
    const int8* filter_data = GetTensorData<int8>(filter);
    const RuntimeShape& bias_shape = GetTensorShape(bias);
    const int32* bias_data = GetTensorData<int32>(bias);
    const RuntimeShape& output_shape = GetTensorShape(output);
    int8* output_data  = GetTensorData<int8>(output);

    const int strW = params->stride_width;
    const int strH = params->stride_height;
    const int dilW = params->dilation_width_factor;
    const int dilH = params->dilation_height_factor;
    int padW = params->pad_width;
    int padH = params->pad_height;

    // 2022/11/12 pytorch->tflite->delete Pad : padding adjust
    padW += (strW > 1);
    padH += (strH > 1); 

    const int32 in_offs  = params->input_offset;
    const int32 out_offs = params->output_offset;

    int32_t* output_multiplier = params->per_channel_multiplier;
    //    int* output_shift = params->per_channel_shift;

    const int inH   = input_shape.Dims(1);
    const int inW   = input_shape.Dims(2);
    const int inC   = input_shape.Dims(3);
    const int filH  = filter_shape.Dims(1);
    const int filW  = filter_shape.Dims(2);
    const int filC  = filter_shape.Dims(3);
    const int outH  = output_shape.Dims(1);
    const int outW  = output_shape.Dims(2);
    const int outC  = output_shape.Dims(3);
    const int fil_size = filH * filW * filC;

    const int depthmul = dwen ? params->depth_multiplier : 1;
    int ch1C = dwen ? inC : outC;
    int ch2C = dwen ? 1 : inC;
    int finc = dwen ? filC : 1;
    int pH = outW * outH; // (outWH + (Np-1)) / Np

#define PACK3(a,b,c)    (((a)<<6)|((b)<<3)|(c))


    set_data(kTfaccOutput, (void*)output_data, output->bytes);
    set_data(kTfaccInput,  (void*)input_data, input->bytes);
    set_data(kTfaccFilter, (void*)filter_data, filter->bytes);
    set_data(kTfaccBias,   (void*)bias_data, bias->bytes);
    set_data(kTfaccQuant,  (void*)output_multiplier, bias->bytes);
//printf("o:%p i:%p f:%p b:%p q:%p\n", output_data,input_data,filter_data,bias_data,output_multiplier);
//    short_dump(n_stage, input_data, filter_data, bias_data, output_multiplier);
    if(is_first_node(nix)) n_stage = 0;
    set_param(kTfaccNstage, n_stage);    // nstage
    set_param(kTfaccDWen,   dwen); // dwen
    set_param(kTfaccRun,    0);    // run

    set_accparam(0, inH);
    set_accparam(1, inW);
    set_accparam(2, inC);
    set_accparam(3, filH);
    set_accparam(4, filW);
    set_accparam(5, filC);
    set_accparam(6, outH);
    set_accparam(7, outW);
    set_accparam(8, outC);
    set_accparam(9, pH);
    set_accparam(10, PACK3(strH,dilH,padH));
    set_accparam(11, PACK3(strW,dilW,padW));
    set_accparam(12, depthmul);
    //    set_accparam(13, actmin);
    //    set_accparam(14, actmax);
    set_accparam(15, in_offs);
    //    set_accparam(16, fil_offs);
    set_accparam(17, out_offs);
    //    set_accparam(18, out_mult>>15);
    //    set_accparam(19, -out_shift);

    set_param(kTfaccRun, 1);    // run tfacc
    kick_tfacc();

#ifdef ULTRA96
    int wc = 0;
    while(get_param(kTfaccRun)) // wait for run complete
        wc++;
    get_outdata((uint8_t*)output_data, output->bytes);
//    printf(" run wait %d om:%d %d\n", wc,output_multiplier[0]>>16,(int8)(output_multiplier[0]&0xff));
//    short_dump(n_stage, input_data, filter_data, bias_data, output_multiplier, output_data);

    n_stage++;
    return kTfLiteOk;
#endif

    if(dumpfrom <= n_stage && dumpto >= n_stage){
        char fn[80];
        sprintf(fn, "tvec/tdump-%d-i8.in", n_stage);
        fprintf(stderr,"*** dump : %s\n", fn);
        dfp1 = fopen(fn, "w");
        fprintf(dfp1,"-1: dwen %d\n",dwen);
        fprintf(dfp1,"0: inH %d\n",inH);
        fprintf(dfp1,"1: inW %d\n",inW);
        fprintf(dfp1,"2: inC %d\n",inC);
        fprintf(dfp1,"3: filH %d\n",filH);
        fprintf(dfp1,"4: filW %d\n",filW);
        fprintf(dfp1,"5: filC %d\n",filC);
        fprintf(dfp1,"6: outH %d\n",outH);
        fprintf(dfp1,"7: outW %d\n",outW);
        fprintf(dfp1,"8: outC %d\n",outC);
        fprintf(dfp1,"9: pH %d\n",pH);
        fprintf(dfp1,"10: {strH,dilH,padH} %d\n",PACK3(strH,dilH,padH));
        fprintf(dfp1,"11: {strW,dilW,padW} %d\n",PACK3(strW,dilW,padW));
        fprintf(dfp1,"12: depthmul %d\n",depthmul);  //
                fprintf(dfp1,"13: actmin %d\n",-128);
                fprintf(dfp1,"14: actmax %d\n",127);
        fprintf(dfp1,"15: in_offs %d\n",in_offs);
                fprintf(dfp1,"16: fil_offs %d\n",0);
        fprintf(dfp1,"17: out_offs %d\n",out_offs);
                fprintf(dfp1,"18: out_mult %d\n",0);
                fprintf(dfp1,"19: out_shift %d\n",0);
        fprintf(dfp1,"input: %zd\n", input->bytes);
        fprintf(dfp1,"filter: %zd\n", filter->bytes);
        fprintf(dfp1,"bias: %zd\n", bias->bytes);
        fprintf(dfp1,"output: %zd\n", output->bytes);
        fwrite(input_data, 1, input->bytes, dfp1);
        fwrite(filter_data, 1, filter->bytes, dfp1);
        fwrite(bias_data, 1, bias->bytes, dfp1);
        fwrite(output_multiplier, 1, bias->bytes, dfp1);
    }
    fprintf(stderr,"%2d %sconv: (acc x %d >>%2d+15)%+4d ",n_stage, dwen?"dw":"  ",
            output_multiplier[0]>>16,(int8)(output_multiplier[0]&0xff),out_offs);
    fprintf(stderr,"o: %3d %3d %3d f: %3d %3d %3d (%4x) i: %3d %3d %3d  %d  %d %d  %d %d  %d %d\n",
            outH,outW,outC, filH,filW,filC, fil_size, inH,inW,inC,
            depthmul,strH,strW,dilH,dilW,padH,padW);

#define CH_PARA

#ifdef CH_PARA
//-- channel parallel test
#if 0
    int filp_inc = filH * filW * ch2C;
    int Noutc = ch1C*depthmul;
    if(Noutc % 4) {
        fprintf(stderr, "Noutc (%d) is not a multiple of 4\n", Noutc);
        Noutc = (Noutc + 3) & ~3;
    }
    int filter_ttl = filp_inc * Noutc;
    uint32* filpdata = (uint32*)malloc(filter_ttl);
    int8*  filpdatapt = (int8*)filpdata;
    // re-order filter access sequence
//    fprintf(stderr, "filp_inc:%d filter_ttl:%d (+%d) ch1C*depthmul:%d Noutc:%d\n", filp_inc, filter_ttl, filter_ttl-filter->bytes, ch1C*depthmul, Noutc);
    for (int out_c = 0; out_c < ch1C*depthmul; out_c++) {
        int ch = out_c & 0x3;
        const int ch1 = out_c / depthmul;
        const int8* filpt = dwen ? &filter_data[out_c] : &filter_data[fil_size * ch1];
        for (int ix = 0; ix < filH*filW*ch2C; ++ix) {
            int8 fil_d = *filpt;
            filpt += finc;
            filpdatapt[ix * 4 + ch] = fil_d;
        }
        if(ch == 3)
            filpdatapt += filp_inc * 4;
    }
    if(0 && n_stage == 1){
        printf("o: %3d %3d %3d f: %3d %3d %3d (%4x) i: %3d %3d %3d\n",
            outH,outW,outC, filH,filW,filC, fil_size, inH,inW,inC);
        for(int i = 0; i < 64; i++) printf(" %02x", (uint8_t)filter_data[i]);
        printf("\n");
        for(int i = 0; i < 64; i+=4) printf("%d %08x\n", i, filpdata[i/4]);
    }
#else
    uint32* filpdata = (uint32*)filter_data; 
    int8*  filpdatapt = (int8*)filpdata;
#endif
    int8* outpt = output_data;
    int in_y0 = - padH;
    int ncc;
    for (int out_y = 0; out_y < outH; ++out_y, in_y0 += strH) {
        int in_x0 = - padW;
        for (int out_x = 0; out_x < outW; ++out_x, in_x0 += strW) {
            filpdatapt = (int8*)filpdata;   // reset filter pointer
            for (int out_c = 0; out_c < ch1C*depthmul; out_c += 4) {
                const int ch1 = out_c / depthmul;
                int32 acc[4] = {0,0,0,0};
                //const int8* filpt = dwen ? &filter_data[out_c] : &filter_data[fil_size * ch1];
                for (int fil_y = 0; fil_y < filH; ++fil_y) {
                    const int in_y = in_y0 + dilH * fil_y;
                    const int in_y_valid = (in_y >= 0) && (in_y < inH);
                    const int in_y_ofs = in_y * inW * inC;
                    const int8* inpt = dwen ? &input_data[in_y_ofs + ch1] : &input_data[in_y_ofs];
                    for (int fil_x = 0; fil_x < filW; ++fil_x) {
                        const int in_x = in_x0 + dilW * fil_x;
                        const int in_valid = (in_x >= 0) && (in_x < inW) && in_y_valid;
                        const int8* inpt2 = &inpt[in_x * inC];
                        for (int in_c = 0; in_c < ch2C; ++in_c) {
                            // If the location is outside the bounds of the input image,
                            // use zero as a default value.
                            for(int cc = 0; cc < 4; cc++){
                                //int32 fil_d = *filpt;
                                int32 fil_d = filpdatapt[cc];
                                //filpt += finc;
                                int32 in_d = 0;
                                if (in_valid) {
                                    in_d = dwen ? inpt2[in_c+cc] : inpt2[in_c];
                                    acc[cc] += fil_d * (in_d + in_offs);
                                }
                                if(n_stage==0 && out_y==41 && out_x==31 && out_c == 0 && cc == 0)
                                    printf("%d %d %d %d %02x %02x %d %x\n", cc,fil_y,fil_x,in_c,(uint8_t)fil_d, (uint8_t)in_d, acc[cc],in_y_ofs+in_x*inC+in_c);
                            }
                            //if(n_stage==23 && out_y==37 && out_x==24)
                            //    printf("%d %d %d %d\n", out_c, fil_y, fil_x, in_c);
                            filpdatapt += 4;
                        }
                    }
                }
                ncc = ch1C*depthmul - out_c;
                ncc = ncc >= 4 ? 4 : ncc;
                for(int cc = 0; cc < ncc; cc++){
                    if (bias_data) {
                        acc[cc] += bias_data[out_c+cc];
                    }
                    //int dbg = _Offset(output_shape, 0, out_y, out_x, out_c) == 0xd3;
                    acc[cc] = limit_i8(_MultiplyByQuantizedMultiplier(acc[cc], output_multiplier[out_c+cc]) + out_offs);
                    outpt[out_c+cc] = static_cast<int8>(acc[cc]);
                }
                //output_data[_Offset(output_shape, batch, out_y, out_x, out_c)] = static_cast<uint8>(acc);
            }
            outpt += ch1C*depthmul;
        }
    }
    //if(ncc < 4) fprintf(stderr," %d(%d)", ncc, ch1C*depthmul);

    //free(filpdata);

#else
    /*    fprintf(stderr,"%2d in:%p,%d fil:%p bias:%p out:%p,%d %x\n", n_stage, input_data, in_cma((void*)input_data), filter_data, bias_data, output_data,
 in_cma(output_data), (uint32_t)cma_get_phy_addr(output_data));
     */
    int8* outpt = output_data;
    //    uint8* refout = (uint8*)malloc(output->bytes);
    //    uint8* outpt = refout;
    int in_y0 = - padH;

    for (int out_y = 0; out_y < outH; ++out_y, in_y0 += strH) {
        int in_x0 = - padW;
        for (int out_x = 0; out_x < outW; ++out_x, in_x0 += strW) {
            for (int out_c = 0; out_c < ch1C*depthmul; out_c++) {
                //for (int ch1 = 0; ch1 < ch1C; ++ch1) {
                //for (int m = 0; m < depthmul; m++) {
                //const int out_c = m + ch1 * depthmul;
                const int ch1 = out_c / depthmul;
                int32 acc = 0;
                const int8* filpt = dwen ? &filter_data[out_c] : &filter_data[fil_size * ch1];

                for (int fil_y = 0; fil_y < filH; ++fil_y) {
                    const int in_y = in_y0 + dilH * fil_y;
                    const int in_y_valid = (in_y >= 0) && (in_y < inH);
                    const int in_y_ofs = in_y * inW * inC;
                    const int8* inpt = dwen ? &input_data[in_y_ofs + ch1] : &input_data[in_y_ofs];
                    for (int fil_x = 0; fil_x < filW; ++fil_x) {
                        const int in_x = in_x0 + dilW * fil_x;
                        const int in_valid = (in_x >= 0) && (in_x < inW) && in_y_valid;
                        const int8* inpt2 = &inpt[in_x * inC];
                        for (int in_c = 0; in_c < ch2C; ++in_c) {
                            // If the location is outside the bounds of the input image,
                            // use zero as a default value.
                            int32 fil_d = *filpt;
                            filpt += finc;
                            int32 in_d = 0;
                            if (in_valid) {
                                in_d = inpt2[in_c];
                                acc += fil_d * (in_d + in_offs);
                            }
                            //if(n_stage==0 && out_y==0 && out_x==0)printf("%d %d %d %d %d %d %d\n", out_c,fil_y,fil_x,in_c,fil_d, in_d, acc);
                        }
                    }
                }
                if (bias_data) {
                    acc += bias_data[out_c];
                }
                //int dbg = _Offset(output_shape, 0, out_y, out_x, out_c) == 0xd3;
                acc = limit_i8(_MultiplyByQuantizedMultiplier(acc, output_multiplier[out_c]) + out_offs);
                //acc = std::max(acc, -128);
                //acc = std::min(acc, 127);
                //output_data[_Offset(output_shape, batch, out_y, out_x, out_c)] = static_cast<uint8>(acc);
                *outpt++ = static_cast<int8>(acc);
            }
        }
    }

#endif

    if(dfp1){
        fwrite(output_data, 1, output->bytes, dfp1);
        fclose(dfp1);
        dfp1 = NULL;
    }

//    short_dump(n_stage, input_data, filter_data, bias_data, output_multiplier, output_data);

    n_stage++;
    return kTfLiteOk;
}

#if 0
//inline
TfLiteStatus Conv2quantPerChannel(
        OpParams *params,
        const TfLiteTensor* input,    // int8
        const TfLiteTensor* filter,   // int8
        const TfLiteTensor* bias,     // int32
        TfLiteTensor* output){  // int8

    const RuntimeShape& input_shape = GetTensorShape(input);
    const int8* input_data = GetTensorData<int8>(input);
    const RuntimeShape& filter_shape = GetTensorShape(filter);
    const int8* filter_data = GetTensorData<int8>(filter);
    const RuntimeShape& bias_shape = GetTensorShape(bias);
    const int32* bias_data = GetTensorData<int32>(bias);
    const RuntimeShape& output_shape = GetTensorShape(output);
    int8* output_data  = GetTensorData<int8>(output);
    int32_t* output_multiplier = params->per_channel_multiplier;
    //    int* output_shift = params->per_channel_shift;

    // Get parameters.
    const int32 input_offset = params->input_offset;  // r = s(q - Z)
    const int stride_width = params->stride_width;
    const int stride_height = params->stride_height;
    const int dilation_width_factor = params->dilation_width_factor;
    const int dilation_height_factor = params->dilation_height_factor;
    const int32 output_offset = params->output_offset;
    const int pad_width = params->pad_width;
    const int pad_height = params->pad_height;

    // Set min and max value of the output.
    const int32 output_activation_min = std::numeric_limits<int8_t>::min();
    const int32 output_activation_max = std::numeric_limits<int8_t>::max();

    // Sanity check.
    TFLITE_DCHECK_LE(output_activation_min, output_activation_max);
    TFLITE_DCHECK_EQ(input_shape.DimensionsCount(), 4);
    TFLITE_DCHECK_EQ(filter_shape.DimensionsCount(), 4);
    TFLITE_DCHECK_EQ(output_shape.DimensionsCount(), 4);
    const int batches = MatchingDim(input_shape, 0, output_shape, 0);
    const int input_depth = MatchingDim(input_shape, 3, filter_shape, 3);
    const int output_depth = MatchingDim(filter_shape, 0, output_shape, 3);
    if (bias_data) {
        TFLITE_DCHECK_EQ(bias_shape.FlatSize(), output_depth);
    }

    // Check dimensions of the tensors.
    const int input_height = input_shape.Dims(1);
    const int input_width = input_shape.Dims(2);
    const int filter_height = filter_shape.Dims(1);
    const int filter_width = filter_shape.Dims(2);
    const int output_height = output_shape.Dims(1);
    const int output_width = output_shape.Dims(2);

    fprintf(stderr,"conv:   (acc x %d >>%2d+15)%+4d %3d %d  ",
            output_multiplier[0]>>16,-(int8)(output_multiplier[0]&0xff),output_offset,
            output_activation_min,output_activation_max);
    fprintf(stderr,"o: %3d %3d %3d f: %3d %3d %3d i: %3d %3d %3d  -  %d %d  %d %d  %d %d\n",
            output_height,output_width,output_depth,filter_height,filter_width,filter_shape.Dims(3),
            input_height,input_width,input_depth,
            stride_height,stride_width,dilation_height_factor,dilation_width_factor,
            pad_height,pad_width);
    //printf("i:%p,%p f:%p b:%p o:%p\n", input, input_data, filter_data, bias_data, output_data);
    int8* outpt = output_data;
    for (int batch = 0; batch < batches; ++batch) {
        for (int out_y = 0; out_y < output_height; ++out_y) {
            for (int out_x = 0; out_x < output_width; ++out_x) {
                for (int out_c = 0; out_c < output_depth; ++out_c) {
                    const int in_x0 = (out_x * stride_width) - pad_width;
                    const int in_y0 = (out_y * stride_height) - pad_height;
                    int32 acc = 0;
                    int8* filpt = (int8*)&filter_data[_Offset(filter_shape, out_c, 0, 0, 0)];
                    for (int fil_y = 0; fil_y < filter_height; ++fil_y) {
                        for (int fil_x = 0; fil_x < filter_width; ++fil_x) {
                            for (int in_c = 0; in_c < input_depth; ++in_c) {
                                const int in_x = in_x0 + dilation_width_factor * fil_x;
                                const int in_y = in_y0 + dilation_height_factor * fil_y;
                                int32 filter_val = *filpt++;
                                // Zero padding by omitting the areas outside the image.
                                const bool is_point_inside_image =
                                        (in_x >= 0) && (in_x < input_width) && (in_y >= 0) &&
                                        (in_y < input_height);
                                if (is_point_inside_image) {
                                    int iofs = _Offset(input_shape, batch, in_y, in_x, in_c);
                                    //printf("i[%d],",iofs);
                                    int32 input_val = input_data[iofs];
                                    //int32 filter_val =
                                    //    filter_data[_Offset(filter_shape, out_c, fil_y,
                                    //                       fil_x, in_c)];
                                    // Accumulate with 32 bits accumulator.
                                    // In the nudging process during model quantization, we force
                                    // real value of 0.0 be represented by a quantized value. This
                                    // guarantees that the input_offset is a int8, even though it
                                    // is represented using int32.
                                    // int32 += int8 * (int8 - int8) so the highest value we can
                                    // get from each accumulation is [-127, 127] * ([-128, 127] -
                                    // [-128, 127]), which is [-32512, 32512]. log2(32512)
                                    // = 14.98, which means we can accumulate at least 2^16
                                    // multiplications without overflow. The accumulator is
                                    // applied to a filter so the accumulation logic will hold as
                                    // long as the filter size (fil_y * fil_x * in_c)
                                    // does not exceed 2^16, which is the case in all the models
                                    // we have seen so far.
                                    // TODO(jianlijianli): Add a check to make sure the
                                    // accumulator depth is smaller than 2^16.
                                    acc += filter_val * (input_val + input_offset);
                                }
                            }
                        }
                    }

                    if (bias_data) {
                        acc += bias_data[out_c];
                    }
                    acc = _MultiplyByQuantizedMultiplier(acc, output_multiplier[out_c]);
                    acc += output_offset;
                    acc = std::max(acc, output_activation_min);
                    acc = std::min(acc, output_activation_max);
                    //output_data[_Offset(output_shape, batch, out_y, out_x, out_c)] = static_cast<int8_t>(acc);
                    *outpt++ = static_cast<int8_t>(acc);
                }
            }
        }
    }
    return kTfLiteOk;
}
#endif

} // tflite
