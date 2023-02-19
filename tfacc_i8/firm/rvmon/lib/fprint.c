
//--------- mini stdio -----------------------------------------------
//
//	2010/04/21
//

#include "stdio.h"
#include <string.h>
#include <stdint.h>
#include <stdarg.h>
//#include "time.h"
#include "ulib.h"
//#include "fat.h"
//#include "ff.h"

FILE _stdio = {{1}, uart_read, uart_write};
////FILE _stdio = {{1}, uart_read, _write};
#define stdout	(&_stdio)
#define stdin	(&_stdio)


//#define FAT_NR_FILE     2	// Number of files which can be opened simultaneously

//static FATFS Fatfs;		/* File system object	*/
//static FIL fil[FAT_NR_FILE];	/* File object		*/
//static FILE fptr[FAT_NR_FILE];	/* stdio File pointer	*/



//---------- memory read / write driver -------------------------------
static ssize_t mem_read(int fd, char *buf, size_t n)
{
    int i = n;
    char **s = (char**)fd;
    while(n--){
        *buf++ = *(*s)++;
    }
    return i;
}
static ssize_t mem_write(int fd, const char *buf, size_t n)
{
    int i = n;
    char **s = (char**)fd;
    while(n--){
        *(*s)++ = *buf++;
    }
    return i;
}
#if 0
//---------- file read / write driver -------------------------------
static ssize_t fat_read(int fd, char *buf, size_t n)
{
    u32 br;
    FRESULT rc;
    rc = f_read(&fil[fd], buf, n, &br);
    return br;
}
static ssize_t fat_write(int fd, const char *buf, size_t n)
{
    u32 br;
    FRESULT rc;
    rc = f_write(&fil[fd], buf, n, &br);
    return br;
}
/*---------------------------------------------------------*/
/* User Provided Timer Function for FatFs module           */
/*---------------------------------------------------------*/
DWORD get_fattime (void)
{
    time_t ltime = get_ltime();
    DWORD fat_tm;
    fat_tm =  ltime.year;
    fat_tm <<= 4;
    fat_tm |= ltime.month;
    fat_tm <<= 5;
    fat_tm |= ltime.day;
    fat_tm <<= 5;
    fat_tm |= ltime.hour;
    fat_tm <<= 6;
    fat_tm |= ltime.min;
    fat_tm <<= 5;
    fat_tm |= (ltime.sec>>1);
    return fat_tm;
}

//--------- file I/O -----------------------------------------------
void mount()
{
    ////	*GPIO = 0x85;
    f_mount(0, &Fatfs);
}

FILE *fopen(const char *path, const char *mode)
{
    int fd, imode;
    FRESULT rc;

    switch(*mode){
    case 'r':
        imode = FA_READ;
        break;
    case 'w':
        imode = FA_WRITE | FA_CREATE_ALWAYS;
        break;
    case 'a':
        imode = FA_READ | FA_WRITE | FA_OPEN_ALWAYS;
        break;
    }
    //	imode = *mode == 'r' ? FA_READ : (*mode == 'w' ? FA_WRITE | FA_CREATE_ALWAYS : FA_READ);

    for(fd = 0; fd < FAT_NR_FILE; fd++){
        if(!fil[fd].fs) break;
    }
    rc = f_open(&fil[fd], path, imode);
    if(rc) return NULL;

    if(*mode == 'a')
        rc = f_lseek(&fil[fd], f_size(&fil[fd]));
    if(rc) return NULL;

    //	fd = fat_open(path, imode);
    //	if(fd < 0) return NULL;

    //	if(*mode == 'w'){	// reopen : prevent write fleeze. fat bug?? 100829
    //		fat_write(fd, &chr, 1);
    //		fat_close(fd);
    //		fd = fat_open(path, imode);
    //		if(fd < 0) return NULL;
    //	}
    fptr[fd].p.fd = fd;
    fptr[fd].read = fat_read;
    fptr[fd].write = fat_write;

    return &fptr[fd];
}

int fclose(FILE *fp)
{
    FRESULT rc;
    rc = f_close(&fil[fp->p.fd]);
    return rc ? EOF : 0;
}
#endif

int fputc(int c, FILE *fp)
{
    char chr = c;
    if((fp->write)(fp->p.fd, &chr, 1) <= 0) return EOF;
    return c;
}

int fputs(const char *s, FILE *fp)
{
    int c;
    while((c = *s++)){
        if(fputc(c, fp) == EOF) return EOF;
    }
    return 0;
}

int putchar(int c)
{
    return fputc(c, stdout);
}

int puts(const char *s)
{
    fputs(s, stdout);
    return putchar('\n');
}


size_t fread(void *pt, size_t size, size_t n, FILE *fp)
{
    return (fp->read)(fp->p.fd, (char*)pt, size*n);
}

size_t fwrite(const void *pt, size_t size, size_t n, FILE *fp)
{
    return (fp->write)(fp->p.fd, (char*)pt, size*n);
}

int fgetc(FILE *fp)
{
    unsigned char chr;
    if((fp->read)(fp->p.fd, (char*)&chr, 1) <= 0) return EOF;
    return chr;
}

char *fgets(char *s, int size, FILE *fp)
{
    int i, c;
    char *p = s;
    for(i = 0; i < size; i++){
        c = fgetc(fp);
        if(c == EOF) return NULL;
        else *p++ = c;
        if(c == '\n') break;
    }
    *p = '\0';
    return s;
}

int getchar(void)
{
    return fgetc(stdin);
}

//--------- printf ------------------------------------------------
#define FLG_LEFT	1
#define FLG_CAPS	2
#define FLG_PAD0	4
#define FLG_UNSGN	8

static int print_str(FILE *fp, const char *str, int digit, int flg)
{
    int c, l = 0, cnt = 0;

    if(digit && !(flg & FLG_LEFT)){
        l = strlen(str);
        while(digit > l){
            if(fputc(' ', fp) == EOF) return EOF;
            digit--;
            cnt++;
        }
    }
    while((c = *str++)){
        if(fputc(c, fp) == EOF) return EOF;
        l++;
        cnt++;
    }
    while(digit > l){
        if(fputc(' ', fp) == EOF) return EOF;
        digit--;
        cnt++;
    }
    return cnt;
}

static int print_hex(FILE *fp, unsigned data, int digit, int flg)
{
    int i, c, l = 0, cnt = 0;
    char buf[8];

    for(i = 7 ; i >= 0 ; i--){
        buf[i] = (data & 0xf);
        data >>= 4;
        l++;
        if(!data){
            break;
        }
    }
    if(digit && !(flg & FLG_LEFT)){
        c = flg & FLG_PAD0 ? '0' : ' ';
        while(digit > l){
            if(fputc(c, fp) == EOF) return EOF;
            digit--;
            cnt++;
        }
    }
    for(; i <= 7 ; i++){
        c = buf[i] > 9 ? buf[i] - 10 + ((flg&FLG_CAPS)?'A':'a') : buf[i] + '0';
        if(fputc(c, fp) == EOF) return EOF;
        cnt++;
    }
    while(digit > l){
        if(fputc(' ', fp) == EOF) return EOF;
        digit--;
        cnt++;
    }
    return cnt;
}

static int print_dec(FILE *fp, int data, int digit, int flg)
{
    int i, c, l = 0, sgn = 0, cnt = 0;
    char buf[11];
    uint32_t udata = data;

    if(!(flg & FLG_UNSGN)){
        if(data < 0){
            sgn = 1;
            udata = -data;
        }
    }
    for(i = 10 ; i > 0 ; i--){
        buf[i] = (udata % 10) + '0';
        udata /= 10;
        l++;
        if(!udata){
            if(sgn){
                if(flg & FLG_PAD0){
                    if(fputc('-', fp) == EOF) return EOF;
                    cnt++;
                }else{
                    buf[--i] = '-';
                }
                l++;
            }
            break;
        }
    }
    if(digit && !(flg & FLG_LEFT)){
        c = flg & FLG_PAD0 ? '0' : ' ';
        while(digit > l){
            if(fputc(c, fp) == EOF) return EOF;
            digit--;
            cnt++;
        }
    }
    for(; i <= 10 ; i++){
        c = buf[i];
        if(fputc(c, fp) == EOF) return EOF;
        cnt++;
    }
    while(digit > l){
        if(fputc(' ', fp) == EOF) return EOF;
        digit--;
        cnt++;
    }
    return cnt;
}

#define MDGT	12
static int print_float(FILE *fp, float data, int digit, int dp, int flg)
{
    int i, c, l = 0, sgn = 0, cnt = 0;
    char buf[MDGT+1];
    int idata, idp = 1;

    for(i = 0; i < dp; i++) idp *= 10;

    if(data < 0.0f){
        sgn = 1;
        data = -data;
    }
    idata = (int)(data * idp + 0.5f);
    i = MDGT;
    if(dp){
        for(; i > 0 ; i--){
            buf[i] = (idata % 10) + '0';
            idata /= 10;
            l++;
            if(l >= dp){
                break;
            }
        }
        buf[--i] = '.';
        i--;
        l++;
    }
    for(; i > 0 ; i--){
        buf[i] = (idata % 10) + '0';
        idata /= 10;
        l++;
        if(!idata){
            if(sgn){
                buf[--i] = '-';
                l++;
            }
            break;
        }
    }
    if(digit && !(flg & FLG_LEFT)){
        c = ' ';
        while(digit > l){
            if(fputc(c, fp) == EOF) return EOF;
            digit--;
            cnt++;
        }
    }
    for(; i <= MDGT ; i++){
        c = buf[i];
        if(fputc(c, fp) == EOF) return EOF;
        cnt++;
    }
    while(digit > l){
        if(fputc(' ', fp) == EOF) return EOF;
        digit--;
        cnt++;
    }
    return cnt;
}
int vfprintf(FILE *fp, const char *fmt, va_list ap)
{
    int d, rv = 0, cnt = 0;
    fu_t f;
//    float ff;
    char c, *s;

    while ((c = *fmt++)){
        int digit = 0, dp = 0;
        int flg = 0;
        if(c == '%'){
            c = *fmt++;
            if(c == 'l'){
                c = *fmt++;
            }else if(c == '-'){
                flg |= FLG_LEFT;
                c = *fmt++;
            }else if(c == '0'){
                flg |= FLG_PAD0;
                c = *fmt++;
            }
            while(c && (c >= '0' && c <= '9')){
                digit = digit * 10 + (c - '0');
                c = *fmt++;
            }
            if(c == '.'){
                c = *fmt++;
                while(c && (c >= '0' && c <= '9')){
                    dp = dp * 10 + (c - '0');
                    c = *fmt++;
                }
            }
            switch(c) {
            case '\0':
                fmt--;
                break;
            case '%':
                rv = fputc(c, fp);
                rv = rv > 0 ? 1 : rv;
                break;
            case 's':
                s = va_arg(ap, char *);
                rv = print_str(fp, s, digit, flg);
                break;
            case 'c':
                c = (char) va_arg(ap, int);
                rv = fputc(c, fp);
                rv = rv > 0 ? 1 : rv;
                break;
            case 'd':
                d = va_arg(ap, int);
                rv = print_dec(fp, d, digit, flg);
                break;
            case 'u':
                d = va_arg(ap, int);
                rv = print_dec(fp, d, digit, flg|FLG_UNSGN);
                break;
            case 'f':
                f.u = va_arg(ap, int);
                rv = print_float(fp, f.f, digit, dp, flg);
                //ff = va_arg(ap, double);
                //rv = print_float(fp, ff, digit, dp, flg);
                break;
            case 'x':
                d = va_arg(ap, int);
                rv = print_hex(fp, d, digit, flg);
                break;
            case 'X':
                d = va_arg(ap, int);
                rv = print_hex(fp, d, digit, flg | FLG_CAPS);
                break;
            }
        }else{
            rv = fputc(c, fp);
            rv = rv > 0 ? 1 : rv;
        }
        if(rv == EOF) return EOF;
        cnt += rv;
    }
    return cnt;
}

int fprintf(FILE *fp, const char *fmt, ...)
{
    va_list ap;
    int rv;

    va_start(ap, fmt);
    rv = vfprintf(fp, fmt, ap);
    va_end(ap);
    return rv;
}

int _printf(const char *fmt, ...)
{
    va_list ap;
    int rv;

    va_start(ap, fmt);
    rv = vfprintf(stdout, fmt, ap);
    va_end(ap);
    return rv;
}

int sprintf(char *str, const char *fmt, ...)
{
    va_list ap;
    int rv;
    FILE fp = {{(int)&str}, mem_read, mem_write};
    va_start(ap, fmt);
    rv = vfprintf(&fp, fmt, ap);
    *str = '\0';
    va_end(ap);
    return rv;
}

#if 0
int main()
{
    int i, j;
    char *fmt, str[200];
    char *_fmt[] ={
            "%d|%13d|%%|%-13d|%s|%20s|%-20s|\n",
            "%x|%13x|%%|%-13x|%s|%20s|%-20s|\n",
            "%X|%13X|%%|%-13X|%s|%20s|%-20s|\n",
            "%X|%013X|%%|%-013X|%s|%20s|%-20s|\n",
            "%d|%013d|%%|%-013d|%s|%20s|%-20s|\n",
            "%d|%02d|%%|%-02d|%s|%20s|%-20s|\n"
    };

    for(j = 0; j < sizeof(_fmt)/sizeof(char*); j++){
        fmt = _fmt[j];
        printf("****************%s", fmt);
        for(i = -100; i < 100; i+=9){
            fprintf(stdout, fmt, i, i, i, "string", "string", "string");
            sprintf(str, fmt, i, i, i, "string", "string", "string");
            fputs(str, stdout);
        }
    }
    fmt = "|%.1f|%6.2f|%-6.3f|\n";

    for(i = -100; i < 100; i+=9){
        float fi = i * 0.01f;
        fprintf(stdout, fmt, fu(fi), fu(fi), fu(fi));
    }
    return 0;
}
#endif
