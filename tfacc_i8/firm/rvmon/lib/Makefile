#
# 2010/04/20	mini-stdio library
#
#ARCH = rv32emc
ARCH = rv32emczfinx

PREFIX  = /opt/rv32e/bin/riscv32-unknown-elf-
MFLAG   = -march=$(ARCH) -mabi=ilp32e

CC	= $(PREFIX)gcc
LD	= $(PREFIX)ld
AR	= $(PREFIX)ar
OBJCP	= $(PREFIX)objcopy
OBJDUMP	= $(PREFIX)objdump

CFLAGS	= -g -Wall $(MFLAG) -nostartfiles -O2 -I../include -DTXIRQ

LDFLAGS = -g -Wall $(MFLAG) -nostdlib
ARFLAGS	= crs

SRCS1    = ulib.c uartdrv.c fprint.c strtok.c strlen.c memclr.c readline.c
OBJS1    = $(SRCS1:.c=.o)
DEPS    = $(SRCS1:.c=.dep)

all:	libmc.a fprintf

fprintf:	fprintf.c
	gcc -O2 -Wall fprintf.c -o fprintf

libmc.a:	$(OBJS1)
	$(AR) $(ARFLAGS) libmc.a $(OBJS1)

%.lst:	%.o
	$(OBJDUMP) -D -S -h $< > $@

%.o:	%.c
	$(CC) $(CFLAGS) -c $<

%.dep:	%.c
	$(CPP) $(CFLAGS) -MM $< > $@

clean:
	@rm -f *.abs *.o core* a.out *~ \#*\#  *.map *.lst *.dep *.bak libmc.a fprintf

depend:	$(DEPS)
	cp Makefile Makefile.bak
	sed '/^#----- dependences -----/q' Makefile.bak >Makefile
	echo >>Makefile
	cat *.dep >>Makefile
	rm -f *.dep

#----- dependences -----

fprint.o: fprint.c ../include/stdio.h ../include/types.h \
 ../include/stdint.h ../include/ulib.h ../include/time.h \
 ../include/ulib.h ../include/uartdrv.h
memclr.o: memclr.c
readline.o: readline.c ../include/stdio.h ../include/types.h \
 ../include/stdint.h ../include/readline.h
strlen.o: strlen.c
strtok.o: strtok.c
uartdrv.o: uartdrv.c ../include/stdio.h ../include/types.h \
 ../include/stdint.h ../include/ulib.h ../include/time.h \
 ../include/ulib.h ../include/uartdrv.h
ulib.o: ulib.c ../include/stdio.h ../include/types.h ../include/stdint.h \
 ../include/ulib.h ../include/time.h ../include/ulib.h \
 ../include/uartdrv.h ../include/time.h
