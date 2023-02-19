
// xlnk wrapper
//
unsigned long cma_mmap(unsigned long offset, uint32_t len);
uint32_t cma_munmap(void *buf, uint32_t len);

void cma_flush_cache(void *buf, unsigned int phys_addr, int size);
void cma_invalidate_cache(void *buf, unsigned int phys_addr, int size);

void *cma_alloc(uint32_t len, uint32_t cacheable);
void cma_free(void *buf);

unsigned long cma_get_phy_addr(void *buf);

