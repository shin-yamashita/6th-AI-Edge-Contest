#
#

CC		= gcc
LINKER		= $(CC)

CFLAGS		= -g -O2 -Wall

LDFLAGS		= -g -O2 -Wall
LDLIBS		= 

SRCS	= term.c 

all:	term 

term:	term.o
	$(CC) -o $@ $(LDFLAGS) $< $(OBJS)

%.o:	%.c
	$(CC) $(CFLAGS) -c $<

clean:;		rm -f term *.o core a.out *~ \#*\# *.bak ;\

###

depend:	$(SRCS)
	cp Makefile Makefile.bak
	sed "/^#----- dependences -----/q" Makefile.bak >Makefile
	echo >>Makefile
	$(CC) $(CFLAGS) -MM $(SRCS) >>Makefile

#----- dependences -----

term.o: term.c
