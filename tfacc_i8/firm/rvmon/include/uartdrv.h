
#ifndef _UARTDRV_H
#define _UARTDRV_H

#include "types.h"

//void select_uart(int bt);
_BEGIN_STD_C

void uart_tx(unsigned char data);
int uart_rx_ready(void);
void uart_set_baud(int brreg);

void txirq_handl();
void uart_putc(char c);
unsigned char uart_rx(void);

ssize_t uart_read(int fd, char *buf, size_t count);
ssize_t uart_write(int fd, const char *buf, size_t count);

_END_STD_C

#endif // _UARTDRV_H
