#
# 2007/04/09  sr_test compile for sr cpu
# 2014/12/09  gcc-4.6.3 xgcc test
# 2017/03/20  risc-v test
# 2022/11/03  rv32_core fpu support (Zfinx)

#ARCH = rv32ec
#ARCH = rv32em
#ARCH = rv32emc
#ARCH = rv32emzfinx
ARCH = rv32emczfinx

PREFIX  = /opt/rv32e/bin/riscv32-unknown-elf-
MFLAG   = -march=$(ARCH) -mabi=ilp32e

CC	= $(PREFIX)gcc
CPP	= $(PREFIX)g++
LD	= $(PREFIX)ld
RUN	= $(PREFIX32)run
OBJCP	= $(PREFIX)objcopy
OBJDUMP	= $(PREFIX)objdump

#CFLAGS	= -g -Wall -nostartfiles -O2
CFLAGS	= -g -Wall -O $(MFLAG)  -nostartfiles -I./include 
CPPFLAGS = $(CFLAGS) -fno-threadsafe-statics

#LDFLAGS =  -nostdlib -Wl,-Map,$(TARGET).map
LDFLAGS = $(MFLAG) -Wl,-Map,$@.map,-T,rv32ldscr.x  -nostdlib -L./lib
#LDFLAGS = $(MFLAG) -Wl,-Map,$@.map,-T,lnkscr.x  -nostdlib -L./lib

LDLIBS  = -lmc -lm -lc -lgcc

SRCS	= rvmon.c memtst.c
SRCSP   = rv_preproc.cc
# pre_data.c

PRGS    = rvmon
OBJS    = $(SRCS:.c=.o) $(SRCSP:.cc=.o) 
DEPS	= $(OBJS:.o=.dep) crt0.dep
MEM	= $(PRGS).mem
REF	= $(PRGS).ref

all:	$(PRGS) lib/libmc.a

lib/libmc.a:	
	make -C lib

mem:	$(MEM)

list:	$(SRCS:.c=.lst)

ecc:	crt0.o ecc.o
	$(CC) -o $@ $^ $(LDFLAGS) $(LDLIBS)
	
rvmon:	crt0.o $(OBJS) 
	make -C lib
	$(CC) -o $@ $^ $(LDFLAGS) $(LDLIBS)

%.mot:	%
	$(OBJCP) -O srec --srec-forceS3 -S -R .stack $< $@

%.bin:	%
	$(OBJCP) -O binary -S -R .stack $< $@

%.mem:	%.bin
	od -An -tx4 -v $< > $@

%.lst:	%
	$(OBJDUMP) -D -S -h $< > $@
#	$(OBJDUMP) -D -h $< > $@

%.o:	%.c
	$(CC) $(CFLAGS) -c $<

%.o:	%.cc
	$(CPP) $(CPPFLAGS) -c $<

%.o:	%.S
	$(CC) $(CFLAGS) -c $<

install:	rvmon.mot rvmon.mem
	cp -p rvmon.mot ../../../infer/fpga-data
	cp -p rvmon.mem ../../sim/

#rsync:
#	rsync -av --delete ../../../../infer/fpga-data/ u96:app/TF/infer/fpga-data

clean:
	@rm -f $(PRGS) *.o core* a.out *~ \#*\# *.map *.lst *.ref *.gcc *.out *.bin *.mot *.mem
	make clean -C lib

%.dep:	%.c
	$(CC) $(CFLAGS) -MM $< | head -c -1 - > $@
	echo " lib/libmc.a " >> $@

%.dep:	%.S
	$(CC) $(CFLAGS) -MM $< > $@

depend:	$(DEPS)
	cp Makefile Makefile.bak
	sed '/^#----- dependences -----/q' Makefile.bak >Makefile
	echo >>Makefile
	cat *.dep >>Makefile
	rm -f *.dep

#----- dependences -----

crt0.o: crt0.S
pre_data.o: pre_data.c include/stdio.h include/types.h include/stdint.h lib/libmc.a 
rvmon.o: rvmon.c include/stdio.h include/types.h include/stdint.h \
 include/ulib.h include/time.h include/ulib.h include/uartdrv.h \
 include/tfacc.h include/readline.h lib/libmc.a 
