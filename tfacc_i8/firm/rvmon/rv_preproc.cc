//https://pyhaya.hatenablog.com/entry/2018/11/13/215750


#include <math.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>

#include "stdio.h"
#include "tfacc.h"
#include "uartdrv.h"

//typedef union {float f; uint32_t u;} fu_t;

//#define fu(x)	((fu_t*)(&x))->u
//#define uf(x)	((fu_t*)(&x))->f

//#define PREP_BUFSIZE   0x600000

#if 0
 void put_lider(int len, float *lider, int W, float BNDRY, float area, int R45)
 {
    printf("machine: aarch64\n");

    if(!m_reg){
        m_reg = reinterpret_cast<uint32_t*>(cma_mmap(0xa0000000, 0x10000));
        if(!m_reg){
            perror("pp:cma_mmap()\n");
        }
        prep_buf = reinterpret_cast<uint32_t*>(&m_reg[PREP_BUF/4]);
        prept = reinterpret_cast<uint32_t*>(cma_alloc(PREP_BUFSIZE, 1));
        if(!prept){
            perror("pp:cma_alloc()\n");
        }
        prep_buf[0] = cma_get_phy_addr(prept);
        printf("pp:m_reg = %p\n", m_reg);
        printf("pp:prept = %p : %lx\n", prept, cma_get_phy_addr(prept));
    }
    int bev_len = (W * W * 3);  // (bytes)

    float *lpt = (float*)(prept + bev_len * 2 / 4);
    for(int i = 0; i < len; i++){
        //if(i < 10) printf("%8.5f(%08x),", lider[i], ((uint32_t*)lider)[i]);
        *lpt++ = lider[i];
    }
    u32_reg_wr(PREP_LEN, len);  // lider data length (float)
    u32_reg_wr(PREP_W, W);      // bev size
    u32_reg_wr(PREP_BANK, bev_bank);
    float_reg_wr(PREP_BNDRY, BNDRY);
    float_reg_wr(PREP_AREA, area);
    u32_reg_wr(PREP_R45, R45);

    cma_flush_cache((void*)lpt, prep_buf[0], len);
    printf("\n");
    u32_reg_wr(PREP_ST, 1);

 }

#endif

//#define BNDRY   50  // boundary (m)
//static float minX = -BNDRY, maxX = BNDRY, minY = -BNDRY, maxY = BNDRY, minZ = -2.73, maxZ = 1.27;
//typedef union {float f; uint32_t u;} fu_t;

#define _fu(x)	((fu_t*)(&x))->u
#define _uf(x)	((fu_t*)(&x))->f
#define minZ    (-2.73f)
#define maxZ    (1.27f)
#define inv_max_height  (255.0f / (maxZ - minZ))

void preproc_c(int len, float *lider, uint8_t *bev, int bank, int W, float BNDRY, float area, int R45){

//    float minZ = -2.73f, maxZ = 1.27f;
//    float inv_max_height = 255.0f / (maxZ - minZ);
    float m2pix = W / (BNDRY*2);    // length(m) to pixel
    int i, ix, iy, iz, il;
    float x, y, z, inten;
    int bev_size = (W * W * 3);
    float Hc = (float)(W / 2);
    uint8_t *np_bev = (uint8_t*)(bev + (bank ? bev_size : 0));
    uint8_t *p;

    memset(np_bev, 0, bev_size);    // clear BEV

    if(R45){
        for(i = 0; i < len; i++){    // lider : [ ,5]
            y = (lider[0]+lider[1])*(float)M_SQRT1_2; 
            x = (lider[1]-lider[0])*(float)M_SQRT1_2; 
            z = lider[2];
            inten = lider[3];
            lider += 5;
            if(fabsf(y) < BNDRY && fabsf(x) < BNDRY && z >= minZ && z < maxZ){
                iy = (int)(y * m2pix + Hc);  // y
                ix = (int)(x * m2pix + Hc);  // x
                p = &np_bev[(ix + iy * W) * 3]; 
                il = inten * 255.0f; // inten
                iz = (z - minZ) * inv_max_height;
                if(iz > p[1]){
                    p[1] = iz;  // max height
                    p[0] = il;  // intensity
                }
                p[2] += p[2] < 255 ? 1 : 0;     // density count
            }
        }
    }else{
        for(i = 0; i < len; i++){    // lider : [ ,5]
            y = *lider++;
            x = *lider++;
            z = *lider++;
            inten = *lider++;
            lider++;
            if(fabsf(y) < BNDRY && fabsf(x) < BNDRY && z >= minZ && z < maxZ){
                iy = (int)(y * m2pix + Hc);  // y
                ix = (int)(x * m2pix + Hc);  // x
                p = &np_bev[(ix + iy * W) * 3]; 
                il = inten * 255.0f; // inten
                iz = (z - minZ) * inv_max_height;
                if(iz > p[1]){
                    p[1] = iz;  // max height
                    p[0] = il;  // intensity
                }
                p[2] += p[2] < 255 ? 1 : 0;     // density count
            }
        }
    }

    static float larea = 0.0f;
    static uint8_t density_map[256];   // densityMap table

    if(larea != area){  // update densityMap table
        larea = area;
        float density, inv_log64 = 255.0f / logf(64.0f * area);

        for(i = 0; i < 256; i++){
            density = logf(i + 1.0f) * inv_log64;
            density_map[i] = density < 255.0f ? density : 255.0f;
        }
    }

    uint8_t *bevp = &np_bev[2];
    int nhw = W * W;
    for(i = 0; i < nhw; i++){
        *bevp = density_map[*bevp];  // densityMap
        bevp += 3;
    }
    return ;   //
}

int debug = 0;

void run_preproc()
{
    while(1){
        if(uart_rx_ready()) return;
        if(*PREP_ST) {
            int     len     = *PREP_LEN;
            uint8_t *prep_buf = (uint8_t*)(*PREP_BUF);
            int     W       = *PREP_W;
            int     bev_len = (W * W * 3);  // (bytes)
            float   *lider  = (float*)(prep_buf + bev_len * 2);
            int     bank    = *PREP_BANK;
            float   BNDRY   = *PREP_BNDRY;
            float   area    = *PREP_AREA;
            int     R45     = *PREP_R45;
            uint8_t *bev    = prep_buf;

            preproc_c(len, lider, bev, bank, W, BNDRY, area, R45);

            if(debug){
               printf("pp: len:%d lider:%08x bev:%08x bank:%d W:%d BNDRY:%4.1f area:%4.2f R45:%d\n",
                len, lider, bev, bank, W, _fu(BNDRY), _fu(area), R45);
            }
        //    rv_cache_flush();   // flush bev

           *PREP_ST = 0;
        }
    }
}


#if 0
static PyObject* preproc_py(PyObject* self, PyObject* args){
    PyArrayObject *lider_array;
    npy_intp W = 320;
    float BNDRY = 50.0f;
    int R45 = false;

    if (! PyArg_ParseTuple(args,  "O!ifp",  // lider, W
            &PyArray_Type, &lider_array,
            &W,
            &BNDRY,
            &R45 )){
        printf("err: PyArg_ParseTuple()\n");
        return NULL;
    }
    npy_intp *dim1 = PyArray_DIMS(lider_array);
    float *lider = (float*)PyArray_DATA(lider_array);
    float rsize = (608.0 / W);

    return preproc_c(dim1, lider, W, BNDRY, rsize*rsize, R45);  //
}
static char preproc_docs[] = "preproc(lider): sfa pre process\n"; 
                                                         
static PyMethodDef preproc_module_methods[] = {
    {"preproc", (PyCFunction)preproc_py,
        METH_VARARGS, preproc_docs},
    {NULL, NULL, 0, NULL} 
};

static struct PyModuleDef preproc_module_definition = {
    PyModuleDef_HEAD_INIT,
    "preproc",
    "Extension module that provides preproc function",
    -1,
    preproc_module_methods
};

PyMODINIT_FUNC PyInit_preproc(void){
    Py_Initialize();
    import_array();
    return PyModule_Create(&preproc_module_definition);
}
#endif
