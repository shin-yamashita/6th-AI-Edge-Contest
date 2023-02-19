
// time.h
// 2012/08/13
// mm7t RTC enable
//

#ifndef _TIME_H
#define _TIME_H

#include "ulib.h"
//---------------------------------------------------------
struct _time {
        u32 year:6;     // 1980 + year
        u32 month:4;    // 1 - 12
        u32 day:5;      // 1 - 31
        u32 hour:5;     // 0 - 23
        u32 min:6;      // 0 - 59
        u32 sec:6;      // 0 - 59
};
typedef struct _time time_t;
typedef u64 clock_t;

clock_t clock();
#define CLOCKS_PER_SEC ((u64)(f_clk + 0.5))

time_t get_ltime();	// get ltime
time_t set_ltime(int Y, int M, int d, int h, int m, int s);
time_t set_strtime(char *str);
time_t str2time(char *str);

void update_rtc_1s();
int get_ms_timer(); // 0-999 ms

#endif // _TIME_H
