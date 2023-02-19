//
// readline.c
// 2021/07/17
//

#include "stdio.h"
#include <string.h>
#include <ctype.h>
#include "readline.h"

#define MAXHIST     16
#define POOLSIZE    1024
#define MAXBUFF     132

static char pool[POOLSIZE];
static char *hist[MAXHIST], locbuff[MAXBUFF+1];
static int  histpt = 0, nhist = 0, poolpt = 0;

#define EL "\033[0K"   // erase eol
#define BS '\b'     // back space
#define Ctl(x) ((x)&0x3f)

static void (*getchar_hook)(void) = 0;
void add_getchar_hook(void (*hook)(void))
{
    getchar_hook = hook;
}
static int getchar_nbk()
{
    if(getchar_hook) (*getchar_hook)();
    return getchar();
}
static int putchar_nbk(int c)
{
    return putchar(c);
}
static void putstr_nbk(char *str)
{
    int c;
    while((c = *str++)) putchar_nbk(c);
}
static void delchr(char *str)
{
    int c, p = 0;
    if(*str){
        strcpy(str, str+1);
    }else{
        str--;
        *str = '\0';
    }
    putchar_nbk(BS);
    while((c = *str++)){
        putchar_nbk(c);
        p++;
    }
    putstr_nbk(EL);
    while(p--) putchar_nbk(BS);
}
static void inschar(char *str, int c)
{
    int sc;
    sc = c;
    do{
        c = *str;
        *str = sc;
        sc = c;
        str++;
    }while(sc);
    *str = '\0';
}

#define home()  {while(str > s){ putchar_nbk(BS); str--;}}
#define left()  {if(str > s){putchar_nbk(BS); str--;}}
#define right() {if(*str) putchar_nbk(*str++);}

static int getline(char *str, int nmax)
{
    char c, *s = str;
    int i;

    while(*str){
        putchar_nbk(*str++);
    }
    putstr_nbk(EL);
    home();
    do{
        c = getchar_nbk();
        switch(c){
        case '\r':      // ignore cr
        case '\t':      // ignore tab
            break;
        case '\n':      // lf
            //*str++ = '\0';
            //putchar_nbk(c);
            return 0;
            break;
        case 0x7f:
        case '\b':
            if(str > s){
                str--;
                delchr(str);
            }
            break;
        case Ctl('A'):
            home();
            break;
        case Ctl('E'):
            while(*str){
                putchar_nbk(*str);
                str++;
            }
            break;
        case Ctl('F'):
            right();
            break;
        case Ctl('B'):
            left();
            break;
        case Ctl('L'):
            putchar_nbk('\n');
            list_history();
            break;
        case '\033':// ESC
            c = getchar_nbk();
            if ((c == 'O') || (c == '[')) {
                switch (c = getchar_nbk()) {
                case 'A':   // up [prev hist]
                    home();
                    return -1;
                    break;
                case 'B':   // down [next hist]
                    home();
                    return 1;
                    break;
                case 'C':   // right
                    right();
                    break;
                case 'D':   // left
                    left();
                    break;
                }
            }
            break;
        default:
            if(isprint(c)){
                if(*str){
                    inschar(str, c);
                    str++;
                    putchar_nbk(c);
                    putstr_nbk(str);
                    for(i = strlen(str); i > 0; i--){
                        putchar_nbk(BS);
                    }
                }else{
                    *str++ = c;
                    *str = '\0';
                    putchar_nbk(c);
                }
            }
            break;
        }
    }while(c != '\n' && (str - s) < nmax);
    return 0;
}

static char *get_history(int pt)    // pt 0:now -1:prev
{
    pt = pt < -nhist ? -nhist : (pt > 0 ? 0 : pt);
    return hist[(histpt + MAXHIST + pt) % MAXHIST];
}
static int is_allspace(const char *str)
{
    while(*str){
        if(!isspace((u8)(*str))) return 0;
        str++;
    }
    return 1;
}
static char *get_history_top()
{
    return hist[histpt];
}
static void set_history_top(char *str)
{
    char *top = get_history_top();
    strcpy(top, str);
}
void list_history()
{
    int i;
    for(i = nhist; i > 0 ; i--){
        printf("%3d: %s\n", -i, get_history(-i));
    }
}
void add_history (char *string)
{
    int len = strlen(string) + 1;
    if(is_allspace(string) || !strcmp(string, get_history(-1))) return;
    char *top = get_history_top();
    if(len > MAXBUFF){
        string[MAXBUFF] = '\0';
        len = MAXBUFF+1;
    }
    strcpy(top, string);
    top[MAXBUFF] = '\0';
    poolpt += len;
    if(poolpt + MAXBUFF+1 > POOLSIZE){
        poolpt = 0;
    }
    histpt = (histpt + 1) % MAXHIST;
    hist[histpt] = &pool[poolpt];
    *(hist[histpt]) = '\0';
    nhist = nhist < MAXHIST ? (nhist + 1): MAXHIST;
}

char *readline(char *prmpt)
{
    int rv;
    int pt = 0;
    putstr_nbk(prmpt);
    hist[histpt] = &pool[poolpt];
    locbuff[0] = '\0';
    do{
        rv = getline(locbuff, 130);
        if(pt == 0 && rv != 0) set_history_top(locbuff);

        switch(rv){
        case  0:
            add_history(locbuff);
            break;
        case -1:
            if(pt > -nhist) pt--;
            strcpy(locbuff, get_history(pt));
            break;
        case  1:
            pt = pt < 0 ? (pt + 1) : 0;
            strcpy(locbuff, get_history(pt));
            break;
        default: break;
        }
    }while(rv != 0);
    return locbuff;
}

//#define TESTMAIN

#ifdef TESTMAIN
int main(int argc, char *argv[])
{
    char *str;

    while(1){
        str = readline("rdl> ");
        printf("\nstr: %s\n", str);
        if(*str == 'q') break;
    }
    return 0;
}
#endif

