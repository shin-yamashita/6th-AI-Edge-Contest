
#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
//#include "dpi.h"


void reg_wr(int a, int d){
}
void reg_rd(int a, int *d){
}
void nop(){}

#define TFACCFLG   0xffff0300
#define TFACCPARAM 0xffff0400

#define DUMPFN	"tvec/tdump-0-u8.in"

uint8_t *input = NULL, *filter = NULL, *output = NULL, *refout = NULL;
int32_t *bias = NULL;
  size_t input_size, filter_size, bias_size, output_size;

int32_t tfaccparam[30];

int mem_rd(int s, int adr)	// s:0,1,2 in,fil,bias 8,8,32
{
  int rdata = 0;
  switch(s){
  case 0: if(adr < input_size)  rdata = input[adr]; break;
  case 1: if(adr < filter_size) rdata = filter[adr]; break;
  case 2: if(adr < bias_size)   rdata = bias[adr]; break;
  case 3: if(adr < output_size) rdata = refout[adr]; break;
  }
  return rdata;
}

int mem_wr(int adr, int data)
{
  output[adr] = data;
  return output[adr] == refout[adr];
}


int c_main(int st)
{
  int i, rd, n, pdat, dwen;
  char str[81], id[20];
//  size_t input_size, filter_size, bias_size, output_size;
  sprintf(str, "tvec/tdump-%d-u8.in", st);
  FILE *dfp = fopen(str, "r");

  if(dfp){
    while(fgets(str, 80, dfp)){
      sscanf(str, "%d: %s %d\n", &n, id, &pdat);
      printf("%d: %s %d\n", n, id, pdat);
      if(n == -1) dwen = pdat;
      if(n >= 0 && n < 30) tfaccparam[n] = pdat;
      if(n == 19) break;
    }
    fgets(str, 80, dfp);
    sscanf(str, "%s %zd\n", id, &input_size);
    printf("%s: %d\n", id, input_size);
    fgets(str, 80, dfp);
    sscanf(str, "%s %zd\n", id, &filter_size);
    printf("%s: %d\n", id, filter_size);
    fgets(str, 80, dfp);
    sscanf(str, "%s %zd\n", id, &bias_size);
    printf("%s: %d\n", id, bias_size);
    fgets(str, 80, dfp);
    sscanf(str, "%s %zd\n", id, &output_size);
    printf("%s: %d\n", id, output_size);
    input  = (uint8_t*)realloc(input, input_size);
    filter = (uint8_t*)realloc(filter, filter_size);
    bias   = (int32_t*)realloc(bias, bias_size);
    output = (uint8_t*)realloc(output, output_size);
    refout = (uint8_t*)realloc(refout, output_size);
    fread(input, 1, input_size, dfp);
    fread(filter, 1, filter_size, dfp);
    fread(bias, 1, bias_size, dfp);
    fread(refout, 1, output_size, dfp);
    fclose(dfp);
  }else{
    perror(DUMPFN);
  }

  for(i = 0; i < 10; i++) nop();

// depthmul
  if(!dwen) tfaccparam[12] = 0;
  for(i = 0; i <= 19; i++){
    reg_wr(TFACCPARAM + i*4, tfaccparam[i]);
  }
  nop();
  nop();
  reg_wr(TFACCFLG, 1);	// kick
  reg_wr(TFACCFLG, 0);	// kick

  for(i = 0; i <= 19; i++){
    reg_rd(TFACCPARAM + i*4, &pdat);
    fprintf(stderr, "crd a:%d d:%d\n", i, pdat);
  }

}


//--- for tfacc_u8 debug ----
int32_t _MultiplyByQuantizedMultiplier(int32_t x, int32_t quantized_multiplier, int shift) {    // right shift only
    int32_t xx = ((int64_t)x * ((quantized_multiplier)>>15)) >> 16;
    //    int32_t dp = (1 << (-shift-1));
    int32_t mask = (1 << (-shift)) - 1;
    int32_t th = (mask >> 1) + (x < 0);
    int32_t rem = xx & mask;
    return (xx >> -shift) + (rem > th);
}


void Conv3quant(){

    const int strW = (tfaccparam[11]>>6);
    const int strH = (tfaccparam[10]>>6);
    const int dilW = (tfaccparam[11]>>3)&0x3;
    const int dilH = (tfaccparam[10]>>3)&0x3;
    const int padW = tfaccparam[11]&0x3;
    const int padH = tfaccparam[10]&0x3;
    const int32_t actmin = tfaccparam[13];
    const int32_t actmax = tfaccparam[14];

    const int32_t in_offs  = tfaccparam[15];
    const int32_t fil_offs = tfaccparam[16];
    const int32_t out_offs = tfaccparam[17];
    const int32_t out_mult = tfaccparam[18];
    const int out_shift  = tfaccparam[19];

    const int inH   = tfaccparam[0];
    const int inW   = tfaccparam[1];
    const int inC   = tfaccparam[2];
    const int filH  = tfaccparam[3];
    const int filW  = tfaccparam[4];
    const int filC  = tfaccparam[5];
    const int outH  = tfaccparam[6];
    const int outW  = tfaccparam[7];
    const int outC  = tfaccparam[8];
    const int fil_size = filH * filW * filC;

    int dwen = tfaccparam[12];
    const int depthmul = tfaccparam[12];
    int ch1C = dwen ? inC : outC;
    int ch2C = dwen ? 1 : inC;
    int finc = dwen ? filC : 1;
    int pH = tfaccparam[9];

    uint8_t* outpt = refout;

    int in_y0 = - padH;
    for (int out_y = 0; out_y < outH; ++out_y, in_y0 += strH) {
        int in_x0 = - padW;
        for (int out_x = 0; out_x < outW; ++out_x, in_x0 += strW) {
            for (int out_c = 0; out_c < ch1C*depthmul; out_c++) {
                //for (int ch1 = 0; ch1 < ch1C; ++ch1) {
                //for (int m = 0; m < depthmul; m++) {
                //const int out_c = m + ch1 * depthmul;
                const int ch1 = out_c / depthmul;
                int32_t acc = 0;
                const uint8_t* filpt = dwen ? &filter[out_c] : &filter[fil_size * ch1];

                for (int fil_y = 0; fil_y < filH; ++fil_y) {
                    const int in_y = in_y0 + dilH * fil_y;
                    const int in_y_valid = (in_y >= 0) && (in_y < inH);
                    const int in_y_ofs = in_y * inW * inC;
                    const uint8_t* inpt = dwen ? &input[in_y_ofs + ch1] : &input[in_y_ofs];
                    for (int fil_x = 0; fil_x < filW; ++fil_x) {
                        const int in_x = in_x0 + dilW * fil_x;
                        const int in_valid = (in_x >= 0) && (in_x < inW) && in_y_valid;
                        const uint8_t* inpt2 = &inpt[in_x * inC];
                        for (int in_c = 0; in_c < ch2C; ++in_c) {
                            // If the location is outside the bounds of the input image,
                            // use zero as a default value.
                            int32_t fil_d = *filpt;
                            filpt += finc;
                            int32_t in_d = 0;
                            if (in_valid) {
                                in_d = inpt2[in_c];
                                acc += (fil_d + fil_offs) * (in_d + in_offs);
                            }
printf("%6x ", in_valid ? &inpt2[in_c] - input : 0);
printf("v:%d i:%2x f:%2x b:%8x\n", in_valid, in_d, fil_d, bias[out_c]);
                       }
                    }
                }
                if (bias) {
                    acc += bias[out_c];
                }
printf("acc:%8x x %d >> %d + %d\n", acc, out_mult, out_shift, out_offs);
                acc = _MultiplyByQuantizedMultiplier(acc, out_mult<<15, -out_shift) + out_offs;
                acc = acc < actmin ? actmin : (acc > actmax ? actmax : acc);
printf("out:%2x r(%2x)\n", acc, *outpt);
                //output_data[_Offset(output_shape, batch, out_y, out_x, out_c)] = static_cast<uint8_t>(acc);
                outpt++;
                //    }
            }
        }
    }

}

int main(int argc, char *argv[])
{
  int adr;
  int stage = 0;
  if(argc > 1) stage = atoi(argv[1]);
  printf("stage %d dump\n", stage);
  c_main(stage);

  Conv3quant();

//  for(adr = 0; adr < filter_size; adr++){
//  for(adr = 0; adr < 4000; adr++){
//    printf("%3x \ti:%2x \tf:%2x \tb:%4x \to:%2x\n", adr, mem_rd(0,adr), mem_rd(1,adr), mem_rd(2,adr), mem_rd(3,adr));
//  }
}



