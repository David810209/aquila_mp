// =============================================================================
//  Program : uartboot.c
//  Author  : Chun-Jen Tsai
//  Date    : Nov/12/2021
// -----------------------------------------------------------------------------
//  Description:
//  This is the boot code for Aquila SoC.  Upon reset, the boot code waiting
//  for an ELF program file to be transferred from the UART port.
//  The processor will be halted when the execution is finished.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  Sep/17/2022, by Chun-Jen Tsai
//    Modify the ELF loader to perform on-the-fly loading from UART without
//    using any ELF file loading buffer.
//
//  Oct/15/2022, by Chun-Jen Tsai
//    Use different schemes for loading into TCM (on-the-fly) and into
//    DRAM (buffered loasding).
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2019,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Yang Ming Chiao Tung Uniersity (NYCU)
//                    Hsinchu, Taiwan.
//
//  All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  1. Redistributions of source code must retain the above copyright notice,
//     this list of conditions and the following disclaimer.
//
//  2. Redistributions in binary form must reproduce the above copyright notice,
//     this list of conditions and the following disclaimer in the documentation
//     and/or other materials provided with the distribution.
//
//  3. Neither the name of the copyright holder nor the names of its contributors
//     may be used to endorse or promote products derived from this software
//     without specific prior written permission.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
//  ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE
//  LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
//  CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
//  SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
//  INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
//  CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
//  ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
//  POSSIBILITY OF SUCH DAMAGE.
// =============================================================================
#include <elf.h>
#include <stdint.h>
#include "io_uart.h"

#define LOCK_0 0x1234
#define LOCK_1 0x5678

#define DONE_0 0x4321
#define DONE_1 0x8765

#define CORE0
#define CORE1
#define MULTICORE

unsigned int print_lock = 0x80000004U;
volatile unsigned int *done_0 = (unsigned int *)0x80000008U;
volatile unsigned int *done_1 = (unsigned int *)0x8000000cU;
volatile unsigned int *prog_ready = (unsigned int *)0x80000000U;


static void setLock(void) {
    asm volatile ("lui t0, %hi(print_lock)");
    asm volatile ("lw t2, %lo(print_lock)(t0)");
    asm volatile ("sw x0, (t2)");
}

__attribute__((optimize("O0"))) static void acquire(void) {
    asm volatile ("lui t0, %hi(print_lock)");
    asm volatile ("lw t2, %lo(print_lock)(t0)");
    asm volatile ("li t0, 1");
    asm volatile ("again:");
    asm volatile ("lw t1, (t2)"); // [t2] initial value is zero.
    asm volatile ("bnez t1, again"); // if [t1] isn't zero , jumo to "again" 
    asm volatile ("amoswap.w.aq t1, t0, (t2)");
    asm volatile ("bnez t1, again");
}

__attribute__((optimize("O0"))) static void release(void) {
    asm volatile ("lui t0, %hi(print_lock)");
    asm volatile ("lw t2, %lo(print_lock)(t0)");
    asm volatile ("amoswap.w.rl x0, x0, (t2)");
}

int load_elf_ddr(Elf32_Ehdr *ehdr);

// ------------------------------------------------------------------------------
//  Memory Map:
//     0x00000000 ~ 0x0000FFFF: on-chip memory (64KB, boot code)
//     0x80000000 ~ 0x8FFFFFFF: main memory (code, data, heap, and stack)
//     0xC0000000 ~ 0xCFFFFFFF: I/O device area
//     0xF0000000 ~ 0xFFFFFFFF: system device area
// ------------------------------------------------------------------------------

uint8_t *prog_1, *prog_2;
uint8_t eheader[64], pheader[128];
char    *organization = "EISL@NYCU, Hsinchu, Taiwan";
int     year = 2023;

uint8_t *elf_base = (uint8_t *) 0x80021000UL; // ELF image buffer

int main(void)
{
    Elf32_Ehdr *ehdr = (Elf32_Ehdr *) eheader;
    uint32_t *magic = (uint32_t *) ELFMAG;
    uint32_t size;
    int idx;
    
    *prog_ready = 0;
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    setLock();
    if(hart_id == 0){
#ifndef CORE0
        while(1);
#else
        *done_0 = 0;
        acquire();
        printf("=======================================================================\n");
        printf("Copyright (c) 2019-%d, %s.\n", year, organization);
        printf("The Aquila SoC is ready.\n");
        printf("Waiting for an ELF file to be sent from the UART ...\n");
        printf("-----------------------------------------------------------------------\n");
        printf("Core %d is waiting for a program to be sent from the UART ...\n", hart_id);
        release();
        // Read the ELF header.
        for (idx = 0; idx < sizeof(Elf32_Ehdr); idx++)
        {
            eheader[idx] = inbyte();
        }

        // Read the Program headers.
        for (idx = 0; idx < ehdr->e_phentsize*ehdr->e_phnum; idx++)
        {
            pheader[idx] = inbyte();
        }

        if (*((uint32_t *) ehdr->e_ident) == *magic)
        {
            prog_1 = (uint8_t *) ehdr->e_entry; /* set program entry point */
            size = ehdr->e_shoff + (ehdr->e_shentsize * ehdr->e_shnum);

            for (idx += sizeof(Elf32_Ehdr); idx < size; idx++)
                elf_base[idx] = inbyte();
            load_elf_ddr(ehdr);
            acquire();
            printf("[Aquila core %d] Load Done!\n", hart_id);          
            printf("[Aquila core %d] Program entry point at 0x%x, size = 0x%x.\n", hart_id, prog_1, size);
            printf("-----------------------------------------------------------------------\n");
            release();
            *prog_ready = LOCK_0;
#ifdef CORE1
            while(*prog_ready != LOCK_1);
#endif
            // Call the entry point for execution.
            asm volatile ("fence.i"); // force flushing of I/D caches.
            asm volatile ("lui t0, %hi(prog_1)");
            asm volatile ("lw ra, %lo(prog_1)(t0)");
            asm volatile ("jalr ra, ra, 0");
            *done_0 = DONE_0;
        }
        else
        {
            acquire();
            printf("\n\nMagic number = 0x%X\n", *((uint32_t *) ehdr->e_ident));
            printf("Error! Not an ELF file.\n\n");
            release();
        }
        *done_0 = DONE_0;
#endif
    }
    else{

#ifndef CORE1
        while(1);
#else
        *done_1 = 0;
        acquire();
        printf("Core %d waiting Core 0 ready...\n", hart_id);
        release();
#ifdef CORE0
        while(*prog_ready != LOCK_0);
#endif
        acquire();
        printf("Core %d is waiting for a program to be sent from the UART ...\n", hart_id);
        release();
        // Read the ELF header.
        for (idx = 0; idx < sizeof(Elf32_Ehdr); idx++)
        {
            eheader[idx] = inbyte();
        }

        // Read the Program headers.
        for (idx = 0; idx < ehdr->e_phentsize*ehdr->e_phnum; idx++)
        {
            pheader[idx] = inbyte();
        }

        if (*((uint32_t *) ehdr->e_ident) == *magic)
        {
            prog_2 = (uint8_t *) ehdr->e_entry; /* set program entry point */
            size = ehdr->e_shoff + (ehdr->e_shentsize * ehdr->e_shnum);

            for (idx += sizeof(Elf32_Ehdr); idx < size; idx++)
                elf_base[idx] = inbyte();
            load_elf_ddr(ehdr);
            acquire();
            printf("[Aquila core %d] Load Done!\n", hart_id);          
            printf("[Aquila core %d] Program entry point at 0x%x, size = 0x%x.\n", hart_id, prog_2, size);
            printf("-----------------------------------------------------------------------\n");
            release();
            *prog_ready = LOCK_1;
            // Call the entry point for execution.
            asm volatile ("fence.i"); // force flushing of I/D caches.
            asm volatile ("lui t0, %hi(prog_2)");
            asm volatile ("lw ra, %lo(prog_2)(t0)");
            asm volatile ("jalr ra, ra, 0");
            *done_1 = DONE_1;
        }
        else
        {
            acquire();
            printf("\n\nMagic number = 0x%X\n", *((uint32_t *) ehdr->e_ident));
            printf("Error! Not an ELF file.\n\n");
            release();
        }
        *done_1 = DONE_1;
#endif
    }
#ifdef MULTICORE
    while(*done_0 != DONE_0 || *done_1 != DONE_1){
    }
    // Halt the processor.
    if(hart_id == 0) {
        exit(0);
    }
    else {
        while(1){
        }
    }
#else
    exit(0);
#endif
    return 0;
}

int load_elf_ddr(Elf32_Ehdr *ehdr)
{
    Elf32_Phdr *section;
    uint32_t dst_addr, src_addr;
    int idx, jdx;

    // Copy all loadable sections of an ELF image to the destination.
    section = (Elf32_Phdr *) pheader;
    for (idx = 0; idx < ehdr->e_phnum; idx++)
    {
        // Locate CODE and DATA sections
        if (section[idx].p_type == PT_LOAD && section[idx].p_filesz != 0)
        {
            src_addr = (uint32_t) elf_base + section[idx].p_offset;
            dst_addr = (uint32_t) section[idx].p_paddr;
            for (jdx = 0; jdx < section[idx].p_filesz; jdx+=sizeof(int))
            {
                *(uint32_t *)(dst_addr+jdx) = *(uint32_t *)(src_addr+jdx);
            }
            while (jdx < section[idx].p_memsz)
            {
                *(uint32_t *)(dst_addr+jdx) = 0;
                jdx += sizeof(int);
            }
        }
    }

    return 0;
}

