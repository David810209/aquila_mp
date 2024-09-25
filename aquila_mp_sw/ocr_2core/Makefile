# ======================================================================
#  This Makefile builds an application *.elf for Aquila.
#
#  Chun-Jen Tsai, Nov/29/2021
# ======================================================================

CROSS = riscv32-unknown-elf
CCPATH = $(RISCV)/bin

CC = $(CCPATH)/$(CROSS)-gcc
LD = $(CCPATH)/$(CROSS)-ld
AR = $(CCPATH)/$(CROSS)-ar
OD = $(CCPATH)/$(CROSS)-objdump
SP = $(CCPATH)/$(CROSS)-strip

GCCVERSION = $(shell $(CC) --version | grep gcc | sed 's/^.* //g')

LIBC = ../elibc
LIBC_OBJS = $(LIBC)/crt0.o $(LIBC)/crt1.o $(LIBC)/stdio.o $(LIBC)/stdlib.o $(LIBC)/string.o $(LIBC)/time.o $(LIBC)/uart.o

LIB_FILE = ./sdcard
LIB_FILE_OBJS = $(LIB_FILE)/sd.o $(LIB_FILE)/spi.o $(LIB_FILE)/fat32.o

CCFLAGS = -Wall -O2 -I$(LIBC) -I$(LIB_FILE) -fno-builtin -march=rv32ima_zicsr_zifencei -mstrict-align -mabi=ilp32
LDFLAGS = -L. -Map=$*.map
LD_SOFT_FP = -L$(RISCV)/lib/gcc/riscv32-unknown-elf/$(GCCVERSION) -lgcc

OCFLAGS = -O binary
ODFLAGS = -d

PROJ ?= ocr_0
OBJS = $(PROJ).o neuronet.o file_read.o
HDRS = neuronet.h file_read.h

all:
	make $(PROJ).elf

clean:
	rm -f *.elf *.objdump *.map *.o *.a

%.o: %.c $(HDRS)
	$(CC) $(CCFLAGS) -c $< -o $@

libelibc.a : $(LIBC_OBJS) $(LIB_FILE_OBJS)
	$(AR) r libelibc.a $(LIBC_OBJS) $(LIB_FILE_OBJS)
	rm $^

%.elf: $(OBJS) libelibc.a
	$(LD) $(LDFLAGS) -T$(PROJ).ld $(OBJS) -lelibc $(LD_SOFT_FP) -o $@
	$(OD) $(ODFLAGS) $@ > $*.objdump
	$(SP) $@
	rm $^

