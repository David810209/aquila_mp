CROSS = riscv32-unknown-elf
CCPATH = $(RISCV)/bin

CC = $(CCPATH)/$(CROSS)-gcc
AR = $(CCPATH)/$(CROSS)-ar

GCCVERSION = $(shell $(CC) --version | grep gcc | sed 's/^.* //g')

LIBC = ./
LIBC_OBJS = $(LIBC)/crt0.o   $(LIBC)/stdio.o $(LIBC)/stdlib.o $(LIBC)/string.o $(LIBC)/time.o $(LIBC)/uart.o

CCFLAGS = -Wall -O2 -I$(LIBC) -fno-builtin -march=rv32ima_zicsr_zifencei -mstrict-align -mabi=ilp32
LD_SOFT_FP = -L$(RISCV)/lib/gcc/riscv32-unknown-elf/$(GCCVERSION) -lgcc -lm

all: libelibc.a

clean:
	rm -f $(LIBC)/*.o libelibc.a

$(LIBC)/%.o: $(LIBC)/%.c
	$(CC) $(CCFLAGS) -c $< -lelibc $(LD_SOFT_FP) -o $@ 

libelibc.a: $(LIBC_OBJS)
	$(AR) rcs $@ $^

.PHONY: all clean

