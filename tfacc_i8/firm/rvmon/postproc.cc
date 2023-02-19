//https://pyhaya.hatenablog.com/entry/2018/11/13/215750

//#define PY_SSIZE_T_CLEAN
//#include <Python.h>
//#include "numpy/arrayobject.h"
#include <math.h>
#include <stdlib.h>

typedef struct detection_ {
    float score;
    int x, y;
    int cls;
} detection_t;

static float sigmoid(float a){
    return 1.0f / (1.0f + expf(-a));
}
static float invsigmoid(float y){
    return -logf(1.0f / y - 1.0f);
}

// NHWC 
#define ix(y,x,c)   ((c)+((x)+(y)*W)*C)

static int is_peak(int x, int W, int C, float *hm)
{
    if(x == 0){
        return hm[0] > hm[C];
    }else if(x >= W-1){
        return hm[0] > hm[-C];
    }else{
        return (hm[-C] < hm[0] && hm[0] > hm[C]);
    }
}

static void compete(detection_t *det, int i, int j, float fth)
{
    if(i == j) return;
    if(abs(det[i].x - det[j].x) < 2 && abs(det[i].y - det[j].y) < 2){
        if(det[i].score > det[j].score) det[j].score = fth;
        else det[i].score = fth;
    }
}

static int comare_score(const void * n1, const void * n2)
{
    if(((detection_t*)n1)->score > ((detection_t*)n2)->score) return -1;
    else if(((detection_t*)n1)->score < ((detection_t*)n2)->score) return 1;
    else return 0;
}

static void center_adj(float *np_det, int x, int y, int W, int C, int downratio, float *cen){
    int ix = (x + y * W) * C;
    float xofs = sigmoid(cen[ix]);
    float yofs = sigmoid(cen[ix+1]);
    np_det[1] = (x + xofs) * downratio;
    np_det[2] = (y + yofs) * downratio;
}

PyObject *postproc_c(int H, int W, int C, float *hm, float *cen, float th, int downratio, int K){  // hm: W x H x 3  cen: W x H x 2
    PyObject *det_array;
    npy_intp dim[2] = {K, 4};
    detection_t *det = NULL;    //(detection_t*)malloc(sizeof(detection_t));
    int Ndet = 0;
    float fth = invsigmoid(th);
    int x, y, ch;
    // hm search
    for(ch = 0; ch < 3; ch++){
        for(y = 0; y < H; y++){
            float *hmp = &hm[ix(y,0,ch)];
            for(x = 0; x < W; x++){
                int xx = x*C;
                if(hmp[xx] > fth){
                    if(is_peak(x, W, C, &hmp[xx])){
                        det = (detection_t*)realloc(det, (Ndet+1)*sizeof(detection_t));
                        det[Ndet].score = hmp[xx];
                        det[Ndet].x = x;
                        det[Ndet].y = y;
                        det[Ndet].cls = ch;
                        Ndet++;
                    }
                }
            }
        }
    }
    // determine the winner between adjacent cells
    int i, j, Nd;
    for(i = 0; i < Ndet; i++){
        for(j = 0; j < Ndet; j++){
            compete(det, i, j, fth-1.0f);
        }
    }
    // sort by score
    qsort(det, Ndet, sizeof(detection_t), comare_score);
    for(i = 0; i < Ndet; i++){
        if(det[i].score < fth) break;
    }
    Ndet = i;

    Nd = K < Ndet ? K : Ndet;
    dim[0] = Nd;
    det_array = PyArray_ZEROS(2, dim, NPY_FLOAT32, 0);
    float *np_det = (float*)PyArray_BYTES((PyArrayObject*)det_array);

    for(i = 0; i < Nd; i++){    // detected score,pos,class -> np.array
    //    printf("%d: %4.2f %2d %2d %d\n", i, sigmoid(det[i].score), det[i].x, det[i].y, det[i].cls);
        np_det[0] = sigmoid(det[i].score);
        center_adj(np_det, det[i].x, det[i].y, W, 2, downratio, cen);   // center offset adjust, 
        np_det[3] = det[i].cls;
        np_det += 4;
    }
    free(det);

    Py_INCREF(det_array);
    return det_array;   // [[score,x,y,cls],[]]
}

static PyObject* postproc_py(PyObject* self, PyObject* args){
    PyArrayObject *hm_array, *cen_array;
    double th;
    npy_intp K = 50;
    npy_intp downratio = 4;

    if (! PyArg_ParseTuple(args,  "O!O!d",  // hm, cen, th
            &PyArray_Type, &hm_array, 
            &PyArray_Type, &cen_array,
            &th)){
        printf("err: PyArg_ParseTuple()\n");
        return NULL;
    }
    npy_intp *dim1;
    dim1 = PyArray_DIMS(hm_array);
#if 0
    npy_intp ndim1, ndim2, *dim2;
    ndim1 = PyArray_NDIM(hm_array);
    ndim2 = PyArray_NDIM(cen_array);
    dim2 = PyArray_DIMS(cen_array);
    int i;  //, x, y, ch;
    for(i = 0; i < ndim1; i++) printf(" %ld,", dim1[i]);
    printf("hm size:%ld itemsz:%ld, data:%p\n"
        , PyArray_SIZE(hm_array), PyArray_ITEMSIZE(hm_array), PyArray_DATA(hm_array));
    for(i = 0; i < ndim2; i++) printf(" %ld,", dim2[i]);
    printf("cen size:%ld itemsz:%ld, data:%p\n"
        , PyArray_SIZE(cen_array), PyArray_ITEMSIZE(cen_array), PyArray_DATA(cen_array));
#endif
    int H = dim1[0], W = dim1[1], C = dim1[2];
    float *hm = (float*)PyArray_DATA(hm_array);
    float *cen = (float*)PyArray_DATA(cen_array);

    return postproc_c(H, W, C, hm, cen, th, downratio, K);  // hm: W x H x 3  cen: W x H x 2
}
static char postproc_docs[] = "postproc(hm,cen): sfa post process\n"; 
                                                         
static PyMethodDef postproc_module_methods[] = {
    {"postproc", (PyCFunction)postproc_py,
        METH_VARARGS, postproc_docs},
    {NULL, NULL, 0, NULL} 
};

static struct PyModuleDef postproc_module_definition = {
    PyModuleDef_HEAD_INIT,
    "postproc",
    "Extension module that provides postproc function",
    -1,
    postproc_module_methods
};

PyMODINIT_FUNC PyInit_postproc(void){
    Py_Initialize();
    import_array();
    return PyModule_Create(&postproc_module_definition);
}
