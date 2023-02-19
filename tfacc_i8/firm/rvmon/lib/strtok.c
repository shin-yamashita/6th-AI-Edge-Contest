//
// mini strtok
//
#include <string.h>

static inline int matchdlm(char c, char *delim)
{
    int sc;
    while ((sc = *delim++)){
        if(c == sc) return 1;	// match
    }
    return 0;
}

char *strtok(char *str, const char *delim)
{
    char *tok;
    static char *saveptr;

    if(str == NULL && (str = saveptr) == NULL) return NULL;

    while(matchdlm(*str, (char*)delim)) str++;
    tok = str;
    while(*str && !matchdlm(*str, (char*)delim)) str++;
    if(*str){
        saveptr = str + 1;
        *str = '\0';
    }else{
        saveptr = NULL;
    }
    return tok;
}

#if 0
#include <stdio.h>
#include <readline/readline.h>
int main()
{
    char *str, *tok;
    while(1){
        str = readline("strtok>");
        tok = strtok(str, " \t,\n");
        while(tok){
            printf("'%s' ", tok);
            tok = strtok(NULL, " \t,\n");
        }
        printf("\n");
    }
}
#endif

