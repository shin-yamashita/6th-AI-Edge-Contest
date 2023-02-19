
// save_data.h
//

typedef struct{
	u32  dadr;
	int  bwl;
	int  run_number;
	int  wref;
	int  dummy[3];
} save_data_t;

save_data_t *get_save_data();	// srmon.c

#define SAVE_DATA	(get_save_data())

