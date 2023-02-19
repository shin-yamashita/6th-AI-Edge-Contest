/*
 * tfacc_u8.cc
 *
 *  Created on: Oct 28, 2020
 *      Author: shin
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <signal.h>

#include "tfacc_u8.h"

static uint32_t* m_reg = NULL;	// rv32_cpu memory area
static volatile uint32_t *accparams = NULL;
//static volatile uint32_t *track_buf = NULL;
//static volatile uint64_t *track_bufvm = NULL;

static uint8_t* tfacc_buf = NULL;	// cma arena area
static uint8_t* last = NULL;
static uint32_t cma_phy_base;
static size_t n_alloc = 0;
static int first_input_node = -1;

static uint8_t* output_buff = NULL;
static uint8_t* input_buff = NULL;
static uint8_t* filter_buff = NULL;
static uint32_t* bias_buff = NULL;
static uint32_t* quant_buff = NULL;
static uint32_t* trkpt = NULL;

static size_t output_buff_size;
static size_t input_buff_size;
static size_t filter_buff_size;
static size_t bias_buff_size;   //(bytes)
static size_t quant_buff_size;   //(bytes)

#define CMA_MAX 0x6000000

#ifndef ULTRA96
uint32_t cma_get_phy_addr(void *pt)
{
    return (uint8_t*)pt - tfacc_buf;
}
void cma_flush_cache(void *buf, unsigned int phys_addr, int size)
{
//    fprintf(stderr, "cma_flush: %p %x %d\n", buf, phys_addr, size);
}
void cma_invalidate_cache(void *buf, unsigned int phys_addr, int size)
{
//    fprintf(stderr, "cma_clean: %p %x %d\n", buf, phys_addr, size);
}
#endif
void PL_if_free()
{
#ifdef ULTRA96
    if(m_reg){
        cma_munmap(m_reg, 0x10000);
        fprintf(stderr, "PL_if_free():cma_munmap\n");
        m_reg = NULL;
    }
    if(tfacc_buf){
        cma_free(tfacc_buf);
        fprintf(stderr, "PL_if_free():cma_free\n");
        tfacc_buf = NULL;
    }
#endif
}
void abort_handle(int sig)
{
    PL_if_free();
}
void PL_if_config()
{
#ifdef ULTRA96
    signal(SIGKILL, abort_handle);
    signal(SIGINT, abort_handle);
    if(!m_reg){
        m_reg = reinterpret_cast<uint32_t*>(cma_mmap(0xa0000000, 0x10000));
        if(!m_reg){
            perror("cma_mmap()\n");
        }
        accparams = reinterpret_cast<uint32_t*>(&m_reg[ACCPARAMS/4]);
    //    track_buf = reinterpret_cast<uint32_t*>(&m_reg[TRACK_BUF/4]);
    //    track_bufvm = reinterpret_cast<uint64_t*>(&m_reg[TRACK_BUFVM/4]);
        fprintf(stderr, "PL_if_config(): m_reg:%p accparam:%p\n", m_reg, accparams);
        atexit(PL_if_free);
    }
    if(!tfacc_buf){
        tfacc_buf = reinterpret_cast<uint8_t*>(cma_alloc(CMA_MAX, 1));   // 64MB cachable
        cma_phy_base = cma_get_phy_addr(tfacc_buf);
        if(!tfacc_buf){
            perror("cma_alloc()\n");
        }
        trkpt = (uint32_t*)(tfacc_buf + 0x2000000);
        fprintf(stderr, "PL_if_config(): tfacc_buf:%p trkpt:%p cma:%p ~ %p\n",
                tfacc_buf, trkpt, cma_phy_base, cma_phy_base+CMA_MAX);
    }
#else
    m_reg = (uint32_t*)malloc(0x10000);
    accparams = &m_reg[ACCPARAMS/4];
//    track_buf = &m_reg[TRACK_BUF/4];
//    track_bufvm = reinterpret_cast<uint64_t*>(&m_reg[TRACK_BUFVM/4]);
    tfacc_buf = (uint8_t*)malloc(CMA_MAX);
    cma_phy_base = 0;
#endif
    output_buff_size = 0;
    input_buff_size = 0;
    filter_buff_size = 0;
    bias_buff_size = 0;
    quant_buff_size = 0;
}
void kick_tfacc()
{
//    printf("kick_tfacc\n");
    m_reg[0x84/4] = 0x1;    // irq register
    m_reg[0x1f0/4] = 0x1;   // rv_shm area 
}
void cma_malloc_init()
{
    PL_if_config();
    last = tfacc_buf;
    n_alloc = 0;
    output_buff = NULL;
}
void *cma_malloc(size_t bytes)  // 16 bytes align
{
    uint8_t *newpt = last;
    bytes = (bytes + 0x1ff) & ~0x1ff;
    n_alloc += bytes;
    last += bytes;
    if(n_alloc >= CMA_MAX){
        fprintf(stderr,"cma_malloc() : memory over  %ld\n", n_alloc);
        exit(-1);
    }
 //   fprintf(stderr,"cma_malloc(%zd) : %p\n", bytes, newpt);
    return newpt;
}

void prepare_buffer_size(TfaccMemory m, size_t bytes)
{
    switch(m){
    case kTfaccOutput:  output_buff_size = output_buff_size < bytes ? bytes : output_buff_size;
        break;
    case kTfaccInput:   input_buff_size = input_buff_size < bytes ? bytes : input_buff_size;
        break;
    case kTfaccFilter:  filter_buff_size = filter_buff_size < bytes ? bytes : filter_buff_size;
        break;
    case kTfaccBias:    bias_buff_size = bias_buff_size < bytes ? bytes : bias_buff_size;
        break;
    case kTfaccQuant:   quant_buff_size = quant_buff_size < bytes ? bytes : quant_buff_size;
        break;
    }
}
void register_input_node(int node){
    if(first_input_node < 0) first_input_node = node;
}
int is_first_node(int node){
    return first_input_node == node;
}

void cma_malloc_buffers()
{
    if(output_buff == NULL){
    //    trkpt =       (uint32_t*)cma_malloc(TRACK_BUFSIZE);
        output_buff = (uint8_t*)cma_malloc(output_buff_size);
        input_buff =  (uint8_t*)cma_malloc(input_buff_size);
        filter_buff = (uint8_t*)cma_malloc(filter_buff_size);
        bias_buff =   (uint32_t*)cma_malloc(bias_buff_size);
        quant_buff =  (uint32_t*)cma_malloc(quant_buff_size);
    //    trkpt =       (uint32_t*)cma_malloc(TRACK_BUFSIZE);
        uint32_t* dmy = (uint32_t*)cma_malloc(TRACK_BUFSIZE);

    //    track_buf[0] = cma_get_phy_addr(trkpt);
    //    track_bufvm[0] = reinterpret_cast<uint64_t>(trkpt);
        fprintf(stderr, "cma_malloc_buffers(): o %ld  i %ld  f %ld  b %ld  n_alloc: %ld\n",
                output_buff_size, input_buff_size, filter_buff_size, bias_buff_size, n_alloc);
        /*
        fprintf(stderr, " output_buff : %8x %x\n", cma_get_phy_addr(output_buff), output_buff_size);
        fprintf(stderr, " input_buff  : %8x %x\n", cma_get_phy_addr(input_buff), input_buff_size);
        fprintf(stderr, " filter_buff : %8x %x\n", cma_get_phy_addr(filter_buff), filter_buff_size);
        fprintf(stderr, " bias_buff   : %8x %x\n", cma_get_phy_addr(bias_buff), bias_buff_size);
        fprintf(stderr, " quant_buff  : %8x %x\n", cma_get_phy_addr(quant_buff), quant_buff_size);
        fprintf(stderr, " trkpt       : %8x %x\n", cma_get_phy_addr(trkpt), TRACK_BUFSIZE);
        */
    }
}

size_t get_cma_malloc_size()
{
    return n_alloc;
}

int in_cma(void *pt)
{
    uint32_t ppt = cma_get_phy_addr(pt);
    return ppt >= cma_phy_base && ppt <= (last-tfacc_buf)+cma_phy_base;
}

void set_param(int n, uint32_t param){
//    if(n < 5)printf("set_param:%d %x\n", n, param);
    if(accparams) accparams[n] = param;
}
uint32_t get_param(int n){
    if(accparams) return accparams[n];
    return -1;
}

void set_data(TfaccMemory m, void *pt, int nbyte)   // 0/1/2/3  out/in/filt/bias
{
    switch(m){
    case kTfaccOutput:
        if(!in_cma(pt)){
            cma_invalidate_cache(output_buff, cma_get_phy_addr(output_buff), nbyte);
            set_param(0, cma_get_phy_addr(output_buff));
            //printf("  (c) set_data(0, %p)\n", cma_get_phy_addr(output_buff));
        }else{
            cma_invalidate_cache(pt, cma_get_phy_addr(pt), nbyte);
            set_param(0, cma_get_phy_addr(pt));
            //printf("  set_data(0, %p)\n", cma_get_phy_addr(pt));
        }
        break;
    case kTfaccInput:
        if(!in_cma(pt)){
            memcpy(input_buff,  pt,  nbyte);
            cma_flush_cache(input_buff, cma_get_phy_addr(input_buff) , nbyte);
            set_param(1, cma_get_phy_addr(input_buff));
        }else{
            cma_flush_cache(pt, cma_get_phy_addr(pt) , nbyte);
            set_param(1, cma_get_phy_addr(pt));
        }
        break;
    case kTfaccFilter:
        if(!in_cma(pt)){
            memcpy(filter_buff,  pt,  nbyte);
            cma_flush_cache(filter_buff, cma_get_phy_addr(filter_buff) , nbyte);
            set_param(2, cma_get_phy_addr(filter_buff));
            //printf(" set_data(pt:%p o:%p)", pt, cma_get_phy_addr(input_buff));
            //for(int i = 0; i < 16; i++)printf(" %2d", (int8_t)input_buff[i]);
            //printf("\n");
        }else{
            cma_flush_cache(pt, cma_get_phy_addr(pt) , nbyte);
            set_param(2, cma_get_phy_addr(pt));
        }
        break;
    case kTfaccBias:
        if(!in_cma(pt)){
            memcpy(bias_buff,  pt,  nbyte);
            cma_flush_cache(bias_buff, cma_get_phy_addr(bias_buff) , nbyte);
            set_param(3, cma_get_phy_addr(bias_buff));
        }else{
            cma_flush_cache(pt, cma_get_phy_addr(pt) , nbyte);
            set_param(3, cma_get_phy_addr(pt));
        }
        break;
    case kTfaccQuant:
        if(!in_cma(pt)){
            memcpy(quant_buff,  pt,  nbyte);
            cma_flush_cache(bias_buff, cma_get_phy_addr(quant_buff) , nbyte);
            set_param(4, cma_get_phy_addr(quant_buff));
        }else{
            cma_flush_cache(pt, cma_get_phy_addr(pt) , nbyte);
            set_param(4, cma_get_phy_addr(pt));
        }
        break;
    }
}

void get_outdata(uint8_t *pt, int nbyte)
{
    if(!in_cma(pt)){
        cma_flush_cache(output_buff, cma_get_phy_addr(output_buff) , nbyte);
        memcpy(pt, output_buff, nbyte);
        //printf(" get_outdata(pt:%p o:%p)", pt, cma_get_phy_addr(output_buff));
        //for(int i = 0; i < 16; i++)printf(" %2d", (int8_t)output_buff[i]);
        //printf("\n");
    }else{
        cma_flush_cache(pt, cma_get_phy_addr(pt) , nbyte);
    }
}

