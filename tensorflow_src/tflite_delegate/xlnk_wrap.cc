
#ifdef ULTRA96

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <unistd.h>

#include <sys/mman.h>
#include <errno.h>

unsigned long cma_mmap(unsigned long offset, uint32_t len)
{
    unsigned long m_reg;
    int fd;
    if ((fd = open("/dev/mem", O_RDWR | O_SYNC)) < 0) {
        perror("cma_mmap() open(/dev/mem)");
        return 0;
    }
    m_reg = (unsigned long)mmap(NULL, len, PROT_READ|PROT_WRITE, MAP_SHARED, fd, offset);
    close(fd);
    if (m_reg == (unsigned long)MAP_FAILED) {
        perror("cma_mmap() mmap()");
        return 0;
    }
    return m_reg;
}

uint32_t cma_munmap(void *buf, uint32_t len)
{
    int rv = munmap(buf, len);
    if(rv < 0){
        perror("cma_munmap()");
    }
    return rv;
}

#include "xrt/xrt.h"

static xclDeviceHandle dhdl;
static xclBufferHandle bohdl;
static uint64_t cma_phy_base;
static uint8_t* cma_mmap_base;

void *cma_alloc(uint32_t len, uint32_t cacheable)
{
    struct xclBOProperties prop;

    dhdl = xclOpen(0, NULL, XCL_INFO);
    bohdl = xclAllocBO(dhdl, len, 0, 0);    // flags? bank info?  
    xclGetBOProperties(dhdl, bohdl, &prop);
    cma_phy_base = prop.paddr;
    cma_mmap_base = (uint8_t*)xclMapBO(dhdl, bohdl, 1);   // read/write
    return cma_mmap_base;
}
void cma_free(void *buf)
{
    xclUnmapBO(dhdl, bohdl, buf);
    xclFreeBO(dhdl, bohdl);
    xclClose(dhdl);
}
unsigned long cma_get_phy_addr(void *buf)
{
    size_t offset = (uint8_t*)buf - cma_mmap_base;
    return cma_phy_base + offset;
}
void cma_flush_cache(void *buf, unsigned int phys_addr, int size)
{
    size_t offset = phys_addr - cma_phy_base;
    xclSyncBO(dhdl, bohdl, XCL_BO_SYNC_BO_TO_DEVICE, size, offset);
}
void cma_invalidate_cache(void *buf, unsigned int phys_addr, int size)
{
    size_t offset = phys_addr - cma_phy_base;
    xclSyncBO(dhdl, bohdl, XCL_BO_SYNC_BO_FROM_DEVICE, size, offset);
}


/*
xclDeviceHandle xclOpen(unsigned int deviceIndex, const char *logFileName, enum xclVerbosityLevel level);
 xclClose(dhdl);
xclBufferHandle xclAllocBO(xclDeviceHandle handle, size_t size,int unused, unsigned int flags);
void xclFreeBO(xclDeviceHandle handle, xclBufferHandle boHandle);

int xclSyncBO(xclDeviceHandle handle, xclBufferHandle boHandle,
          enum xclBOSyncDirection dir, size_t size, size_t offset);
int xclCopyBO(xclDeviceHandle handle, xclBufferHandle dstBoHandle,
          xclBufferHandle srcBoHandle, size_t size, size_t dst_offset,
          size_t src_offset);

enum xclBOSyncDirection {
    XCL_BO_SYNC_BO_TO_DEVICE = 0,
    XCL_BO_SYNC_BO_FROM_DEVICE,
    XCL_BO_SYNC_BO_GMIO_TO_AIE,
    XCL_BO_SYNC_BO_AIE_TO_GMIO,
};

void*
xclMapBO(xclDeviceHandle handle, xclBufferHandle boHandle, bool write);
int
xclUnmapBO(xclDeviceHandle handle, xclBufferHandle boHandle, void* addr);

int
xclGetBOProperties(xclDeviceHandle handle, xclBufferHandle boHandle,
                   struct xclBOProperties *properties);

struct xclBOProperties {
    uint32_t handle;
    uint32_t flags;
    uint64_t size;
    uint64_t paddr;
    int reserved; // not implemented
};
*/
#endif
