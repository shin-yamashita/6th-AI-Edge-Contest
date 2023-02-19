/*
 * tfacc_u8.h
 *
 *  Created on: Oct 28, 2020
 *      Author: shin
 */

#ifndef TFACC_U8_H_
#define TFACC_U8_H_

#include <stdlib.h>
#include <stdint.h>

#ifdef ULTRA96
//extern "C" {
//#include <libxlnk_cma.h>
//}
unsigned long cma_mmap(unsigned long offset, uint32_t len);
uint32_t cma_munmap(void *buf, uint32_t len);
void *cma_alloc(uint32_t len, uint32_t cacheable);
void cma_free(void *buf);
unsigned long cma_get_phy_addr(void *buf);
void cma_flush_cache(void *buf, unsigned int phys_addr, int size);
void cma_invalidate_cache(void *buf, unsigned int phys_addr, int size);

#else
uint32_t cma_get_phy_addr(void *pt);
#endif

typedef enum {
    kTfaccNstage = 5,
    kTfaccDWen,
    kTfaccRun,
} TfaccCtrl;

typedef enum {
    kTfaccOutput = 0,
    kTfaccInput,
    kTfaccFilter,
    kTfaccBias,
    kTfaccQuant,
} TfaccMemory;

//#define TRACK_BUF       (0x000000c0)    // Tracking data buffer pointer phy addr
//#define TRACK_BUFVM     (0x000000d0)    // Tracking data buffer pointer vm addr

#define ACCPARAMS       (0x00000100)
#define TRACK_BUFSIZE   0x600000   // 2048

void cma_malloc_init();
void *cma_malloc(size_t bytes);
void prepare_buffer_size(TfaccMemory m, size_t bytes);
void register_input_node(int node);
int is_first_node(int node);
void cma_malloc_buffers();

//void track_buf_flush();

size_t get_cma_malloc_size();
int  in_cma(void *pt);

// tfacc parameters
void set_param(int n, uint32_t param);
uint32_t get_param(int n);
#define set_accparam(n, p)  set_param(8+(n), (p))

void kick_tfacc();

void set_data(TfaccMemory m, void *pt, int nbyte);
void get_outdata(uint8_t *pt, int nbyte);

#endif // TFACC_U8_H_
