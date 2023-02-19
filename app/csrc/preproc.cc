//https://pyhaya.hatenablog.com/entry/2018/11/13/215750

#define PY_SSIZE_T_CLEAN
#include <Python.h>
#include "numpy/arrayobject.h"
#include <math.h>
#include <stdlib.h>

#ifdef aarch64

#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>
#include <sys/mman.h>
#include "xlnk_wrap.h"

typedef union {float f; uint32_t u;} fu_t;

#define fu(x)	((fu_t*)(&x))->u
#define uf(x)	((fu_t*)(&x))->f

#define PREP_BUFSIZE   0x700000

#define PREP_BUF        (0x000000c0)    // Preproc data buffer addr
#define PREP_ST         (0x000000c4)    // Preproc process status 1:progress
#define PREP_LEN        (0x000000c8)    // lider data length (float word)
#define PREP_W          (0x000000cc)    // BEV H,W size
#define PREP_BANK       (0x000000d0)    // BEV bank 0/1
#define PREP_BNDRY      (0x000000d4)    // BNDRY
#define PREP_AREA       (0x000000d8)    // area
#define PREP_R45        (0x000000dc)    // R45


static uint32_t *m_reg = NULL;
static volatile uint32_t *prep_buf = NULL;
static uint32_t* prept = NULL;
static uint32_t bev_bank = 0;

#define u32_reg_wr(a, d)    (m_reg[(a)/4] = (uint32_t)(d))
#define float_reg_wr(a, d)  (m_reg[(a)/4] = fu(d))
#define u32_reg_rd(a)       (m_reg[(a)/4])
#define float_reg_rd(a)     (uf(m_reg[(a)/4]))


void put_lider(int len, float *lider, int W, float BNDRY, float area, int R45)
{
//    printf("machine: aarch64\n");

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
//    printf("pp:lpt = %p  %lx\n", lpt, cma_get_phy_addr(lpt));
//    printf("pp:len = %d\n", len);
    memcpy(lpt, lider, len*sizeof(float)*5);    // copy lider(vm) to cma area

    u32_reg_wr(PREP_LEN, len);  // lider data length (float)
    u32_reg_wr(PREP_W, W);      // bev size
    u32_reg_wr(PREP_BANK, bev_bank);
    float_reg_wr(PREP_BNDRY, BNDRY);
    float_reg_wr(PREP_AREA, area);
    u32_reg_wr(PREP_R45, R45);

    cma_flush_cache((void*)lpt, cma_get_phy_addr(lpt), len*sizeof(float)*5);
    cma_invalidate_cache((void*)prept, cma_get_phy_addr(prept), bev_len*2);
    u32_reg_wr(PREP_ST, 1); // kick rv32 preproc
}
#endif
//static int bg = 0;

PyObject *preproc_c(npy_intp *dim, float *lider, int W, float BNDRY, float area, int R45, int bg){
    PyObject *bev_array;
    npy_intp dim2[3] = {W, W, 3};
    // 
    bev_array = PyArray_ZEROS(3, dim2, NPY_UINT8, 0);
    uint8_t *np_bev = (uint8_t*)PyArray_BYTES((PyArrayObject*)bev_array);

#ifdef aarch64
    int bev_len = (W * W * 3);  // (bytes)
    if(bg && m_reg){
        int wc = 0;
        uint8_t *rvbev = (uint8_t*)(prept) + (bev_bank ? bev_len : 0);
        //printf("bg:%d ...", bev_bank);
        do{
            usleep(1000);
            wc++;
            //printf(" pp_c:%d\n", wc++);
        }while(u32_reg_rd(PREP_ST) && wc < 2000);
        memcpy(np_bev, rvbev, bev_len);
        bev_bank = !bev_bank;
        //printf(" done\n");
    }
    //printf(" put_lider %d ...", bev_bank);
    put_lider(dim[0], lider, W, BNDRY, area, R45);

    //if(bg) bev_bank = !bev_bank;
#else
    static float minX = -BNDRY, maxX = BNDRY, minY = -BNDRY, maxY = BNDRY, minZ = -2.73, maxZ = 1.27;
    float m2pix = W / (maxX - minX);    // length(m) to pixel
    float inv_max_height = 255.0f / (maxZ - minZ);
    int i, ix, iy, iz, il;
    float x, y, z, inten;

    for(i = 0; i < dim[0]; i++){    // lider : [ ,5]
        if(R45){
            y = (lider[0]+lider[1])*M_SQRT1_2; 
            x = (lider[1]-lider[0])*M_SQRT1_2; 
        }else{
            y = lider[0];
            x = lider[1];
        }
        z = lider[2];
        inten = lider[3];
        lider += dim[1];
        if(y >= minY && y < maxY && x >= minX && x < maxX && z >= minZ && z < maxZ){
            iy = floorf(y * m2pix) + W / 2;  // y
            ix = floorf(x * m2pix) + W / 2;  // x
            uint8_t *p = &np_bev[(ix + iy * W) * 3]; 
            il = inten * 255.0f;
            iz = (z - minZ) * inv_max_height;
            if(iz > p[1]){
                p[1] = iz;  // max height
                p[0] = il;  // intensity
            }
            p[2] += p[2] < 255 ? 1 : 0;     // density count
        }
    }
    uint8_t density_map[256];   // densityMap table
    float density, inv_log64 = 255.0f / logf(64.0f * area);

    for(i = 0; i < 256; i++){
        density = logf(i + 1.0f) * inv_log64;
        density_map[i] = density < 255.0f ? density : 255.0f;
    }
    uint8_t *bevp = &np_bev[2];
    int nhw = W * W;
    for(i = 0; i < nhw; i++){
        *bevp = density_map[*bevp];  // densityMap
        bevp += 3;
    }
#endif

#ifdef aarch64
    if(!bg && m_reg){
        uint8_t *rvbev = (uint8_t*)(prept) + (bev_bank ? bev_len : 0);
        do{
            usleep(1000);
        }while(u32_reg_rd(PREP_ST));
        memcpy(np_bev, rvbev, bev_len);
    }
    //printf(" %d done\n", bev_bank);
#endif

    Py_INCREF(bev_array);
    return bev_array;   //
}

static PyObject* preproc_py(PyObject* self, PyObject* args){
    PyArrayObject *lider_array;
    npy_intp W = 320;
    float BNDRY = 50.0f;
    int R45 = false;
    int bg = false;

    if (! PyArg_ParseTuple(args,  "O!ifpp",  // lider, W
            &PyArray_Type, &lider_array,
            &W,
            &BNDRY,
            &R45,
            &bg )){
        printf("err: PyArg_ParseTuple()\n");
        return NULL;
    }
    npy_intp *dim1 = PyArray_DIMS(lider_array);
    float *lider = (float*)PyArray_DATA(lider_array);
    float rsize = (608.0 / W);

    return preproc_c(dim1, lider, W, BNDRY, rsize*rsize, R45, bg);  //
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
