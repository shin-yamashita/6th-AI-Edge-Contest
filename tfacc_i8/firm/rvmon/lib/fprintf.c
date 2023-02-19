//--------- mini stdio -----------------------------------------------
//
//	2010/04/21
//

#include <stdio.h>
#include <string.h>
#include <stdarg.h>
//#include "types.h"
typedef union {float f; unsigned u;} fu_t;
#define fu(x)   ((fu_t)(x)).u
#define uf(x)   ((fu_t)(x)).f

//--------- printf ------------------------------------------------
#define FLG_LEFT	1
#define FLG_CAPS	2
#define FLG_PAD0	4

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

    if(data < 0){
        sgn = 1;
        data = -data;
    }
    for(i = 10 ; i > 0 ; i--){
        buf[i] = (data % 10) + '0';
        data /= 10;
        l++;
        if(!data){
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
            case 'f':
                f.u = va_arg(ap, int);
                rv = print_float(fp, f.f, digit, dp, flg);
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

#if 0
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
#endif

#if 1
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
