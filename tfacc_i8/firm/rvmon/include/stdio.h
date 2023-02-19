/*
	mini-stdio

	2010/04/21
 */

#ifndef _STDIO_H_
#define _STDIO_H_

#include <_ansi.h>
_BEGIN_STD_C

#include "types.h"

typedef struct {
    union{
        int fd;
        char *pt;
    } p;
    ssize_t (*read)(int fd, char *buf, size_t count);
    ssize_t (*write)(int fd, const char *buf, size_t count);
} FILE;

#ifndef NULL
#define NULL    0
#endif
#define	EOF	(-1)

#include <stdarg.h>
void mount();
FILE *fopen(const char *path, const char *mode);
int  fclose(FILE *fp);
int  fputc(int c, FILE *fp);
int  fputs(const char *s, FILE *fp);
int  putchar(int c);
int  puts(const char *s);
int  fgetc(FILE *fp);
char *fgets(char *s, int size, FILE *fp);
int  getchar(void);
int  vfprintf(FILE *fp, const char *fmt, va_list ap);
int  fprintf(FILE *fp, const char *fmt, ...);
int  _printf(const char *fmt, ...);
int  sprintf(char *str, const char *fmt, ...);
#define printf	_printf

size_t fread(void *pt, size_t size, size_t n, FILE *fp);
size_t fwrite(const void *pt, size_t size, size_t n, FILE *fp);

ssize_t read(int fd, char *buf, size_t count);
ssize_t write(int fd, const char *buf, size_t count);

extern FILE _stdio;
#define stdout  (&_stdio)
#define stdin   (&_stdio)

_END_STD_C

#endif /* _STDIO_H_	*/
