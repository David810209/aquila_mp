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
//    DRAM (buffered loading).
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
#define LOCK_2 0x9abc
#define LOCK_3 0xdef0

#define DONE_0 0x4321
#define DONE_1 0x8765
#define DONE_2 0xcba9
#define DONE_3 0xfed0

volatile unsigned int *prog_ready = (unsigned int *)0x80000000U;
volatile unsigned int *prog = (unsigned int *)0x80000010U;

//for test code
volatile unsigned int *print_lock2 = (unsigned int *)0x80000020U;
volatile unsigned int *done_init = (unsigned int *)0x80000030U;  

int load_elf(Elf32_Ehdr *ehdr);

// ------------------------------------------------------------------------------
//  Memory Map:
//     0x00000000 ~ 0x0000FFFF: on-chip memory (64KB, boot code)
//     0x80000000 ~ 0x8FFFFFFF: main memory (code, data, heap, and stack)
//     0xC0000000 ~ 0xCFFFFFFF: I/O device area
//     0xF0000000 ~ 0xFFFFFFFF: system device area
// ------------------------------------------------------------------------------

uint8_t eheader[64], pheader[128];
char    *organization = "EISL@NYCU, Hsinchu, Taiwan";
int     year = 2023;
int main(void)
{
    Elf32_Ehdr *ehdr = (Elf32_Ehdr *) eheader;
    uint32_t *magic = (uint32_t *) ELFMAG;
    uint32_t size, hsize = sizeof(Elf32_Ehdr);
    int idx;
    *prog_ready = 0;
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    if (hart_id == 0) 
    {   
        printf("=======================================================================\n");
        printf("Copyright (c) 2019-%d, %s.\n", year, organization);
        printf("The Aquila SoC is ready.\n");
        printf("-----------------------------------------------------------------------\n");
        printf("Core %d is waiting for a program to be sent from the UART ...\n", hart_id);

        for (idx = 0; idx < hsize; idx++)
        {
            eheader[idx] = inbyte();
        }
        if (*((uint32_t *) ehdr->e_ident) == *magic)
        {
            *prog = ehdr->e_entry; // set program entry point
            size = ehdr->e_shoff + (ehdr->e_shentsize * ehdr->e_shnum);
            load_elf(ehdr);
            printf("[Aquila core %d] Load Done!\n", hart_id);          
            printf("[Aquila core %d] Program entry point at 0x%x, size = 0x%x.\n", hart_id, *prog, size);
            printf("-----------------------------------------------------------------------\n");
            
            *done_init = 0;
            *print_lock2 = 0;
            // Call the entry point for execution.
            
            asm volatile ("fence.i"); // force flushing of I/D caches.
            *prog_ready = LOCK_0;
            register uint32_t entry = *prog;
            asm volatile ("jalr zero, %0, 0" :: "r"(entry));
        }
        else
        {
            printf("\n\ncore%d: Magic number = 0x%X\n",hart_id,  *((uint32_t *) ehdr->e_ident));
            printf("Error! Not an ELF file.\n\n");
        }
    }
    else   {
        while(*prog_ready != LOCK_0);
        asm volatile ("fence.i"); // force flushing of I/D caches.
        register uint32_t entry = *prog;
        asm volatile ("jalr zero, %0, 0" :: "r"(entry));
    }
   
    while(1);
    return 0;
}

int load_elf(Elf32_Ehdr *ehdr)
{
    uint32_t hsize = sizeof(Elf32_Ehdr);
    uint32_t phdr_size = ehdr->e_phentsize * ehdr->e_phnum;
    uint32_t current_byte = hsize;
    uint32_t skip;
    uint8_t *dst_addr;
    int idx, jdx;
    int has_load = 0;
    // 分配缓冲区来读取程序头
    uint8_t phdr_buffer[phdr_size];

    // 读取程序头到缓冲区
    for (idx = 0; idx < phdr_size; idx++)
    {
        phdr_buffer[idx] = inbyte();
        current_byte++;
    }

    // 将缓冲区转换为 Elf32_Phdr 数组
    Elf32_Phdr *phdr = (Elf32_Phdr *)phdr_buffer;

    // 加载可执行段和数据段到目标地址
    for (idx = 0; idx < ehdr->e_phnum; idx++)
    {
        if (phdr[idx].p_type == PT_LOAD)
        {
            dst_addr = (uint8_t *)phdr[idx].p_paddr;

            // 跳过未读取的字节
            skip = phdr[idx].p_offset - current_byte;
            while (skip-- > 0)
            {
                inbyte();
                current_byte++;
            }

            // 从输入中读取段数据
            for (jdx = 0; jdx < phdr[idx].p_filesz; jdx++)
            {
                dst_addr[jdx] = inbyte();
                current_byte++;
            }

            // 如果 p_memsz > p_filesz，需要将剩余部分置零
            for (; jdx < phdr[idx].p_memsz; jdx++)
            {
                dst_addr[jdx] = 0;
            }

            has_load++;
        }
    }

    return 0;
}