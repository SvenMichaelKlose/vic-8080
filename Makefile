ASMSOURCES=cpu.asm bios.asm calcscr.asm column-addrs.asm cursor.asm moveram.asm print.asm
SOURCES=bdos.c main.c memory.c
PROGRAM=cpm

CC65_HOME = /usr/local
CC65_INCLUDE = $(CC65_HOME)/share/cc65/include/
AS      = $(CC65_HOME)/bin/ca65
CC      = $(CC65_HOME)/bin/cl65
AR      = $(CC65_HOME)/bin/ar65
LD      = $(CC65_HOME)/bin/ld65
CFLAGS  = -O
LDFLAGS = -m $(PROGRAM).map

%.o: %.asm
	$(AS) -o $@ $<

%.o: %.c
	$(CC) -c $(CFLAGS) -o $@ $<

$(PROGRAM): $(SOURCES:.c=.o) $(ASMSOURCES:.asm=.o)
	$(LD) -C vic20.cfg -m $@.map -Ln $(PROGRAM).lst -o $@ $^ /usr/local/share/cc65/lib/vic20.lib

all: $(PROGRAM)

clean:
	rm -f $(ASMSOURCES:.asm=.o) $(SOURCES:.c=.o) $(PROGRAM) $(PROGRAM).lst $(PROGRAM).map
