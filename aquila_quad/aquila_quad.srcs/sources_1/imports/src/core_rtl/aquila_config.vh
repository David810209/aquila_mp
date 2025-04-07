`timescale 1ns / 1ps 
// =============================================================================
//  Program : aquila_config.vh
//  Author  : Chun-Jen Tsai
//  Date    : Aug/23/2022
// -----------------------------------------------------------------------------
//  Description:
//  This is the configuration parameters for the Aquila core.
// -----------------------------------------------------------------------------
//  License information:
//
//  This software is released under the BSD-3-Clause Licence,
//  see https://opensource.org/licenses/BSD-3-Clause for details.
//  In the following license statements, "software" refers to the
//  "source code" of the complete hardware/software system.
//
//  Copyright 2022,
//                    Embedded Intelligent Systems Lab (EISL)
//                    Deparment of Computer Science
//                    National Chiao Tung Uniersity
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

//==============================================================================================
// Parameters and Integers
//==============================================================================================

// The target board can be ARTY or KC705, the MACRO is defined globally
//   in the TCL script when the project was created

`ifdef ARTY
    `define UIADR 28              // DRAM chip addr width
    `define CLP   128             // Cache line size
    `define DRAMA 14              // DRAM chip addr width
    `define DRAMD 16              // DRAM chip bus width
    `define BA    3               // DRAM bank addr width
    `define WDFP  128             // MIG controller user logic data width
    `define DQSP  2               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
    `define SOC_CLK 50_000_000    // system clock rate
`elsif KC705
    `define UIADR 28              // DRAM chip addr width
    `define CLP   256             // Cache line size
    `define DRAMA 14              // DRAM chip addr width
    `define DRAMD 64              // DRAM chip bus width
    `define BA    3               // DRAM bank addr width
    `define WDFP  512             // MIG controller user logic data width
    `define DQSP  8               // MIG DQS parameter
    `define USRP  5               // # of user buttons & LEDs
    `define SOC_CLK 100_000_000   // system clock rate
`else
    `define UIADR 29              // DRAM chip addr width
    `define CLP   256             // Cache line size
    `define DRAMA 17              // DRAM chip addr width
    `define DRAMD 32              // DRAM chip bus width
    `define BA    2               // DRAM bank addr width
    `define WDFP  256             // MIG controller user logic data width
    `define DQSP  4               // MIG DQS parameter
    `define USRP  4               // # of user buttons & LEDs
    `define SOC_CLK 50_000_000    // system clock rate
`endif

// Numbers  of Cores
`define CORE_NUMS 4
//`define CORE_NUM_2
//`define CORE_NUM_3
// `define CORE_NUM_4

// Tightly-Coupled Memory Size
`define TCM_SIZE_IN_WORDS 4096   // 16KB

// DDRx memory is only accessible via cache controller
`define ENABLE_DDRx_MEMORY
`define ICACHE_SIZE 8 // Instruction cache size in KB
`define DCACHE_SIZE 8 // Data cache size in KB
`define L2CACHE_SIZE 64

// Branch Prediction
`define ENABLE_BRANCH_PREDICTION

// Atomic Unit
 `define ENABLE_ATOMIC_UNIT

// Muldiv Integer multiplier
`define ENABLE_FAST_MULTIPLY

// Fetch
`define NOP 32'h00000013

// Monitor D-cache
`define Monitor 1

// SIM_FNAME defines the RISC-V program path of an ELF file for simulation.
//`define SIM_FNAME_0  "/home/zichen/zichen/mpd/aquila_sw/pi/pi.elf"
//`define SIM_FNAME_0  "/home/zichen/zichen/aquila_mp/aquila_mp_sw/ocr_1core/ocr.elf"

//`define SIM_FNAME_0 "/home/zichen/zichen/aquila_mp/sw/coremark_2core/CoreMark/coremark.elf"
//`define SIM_FNAME_0 "/home/zichen/zichen/aquila_mp/aquila_mp_sw/test/test_0.elf"
// `define SIM_FNAME_0  "C:\\zichen\\aquila_mp\\sw\\pi\\pi.elf"
//`define SIM_FNAME_0  "C:\\zichen\\aquila_mp\\sw\\Dhrystone\\dhry.elf"
// `define SIM_FNAME_0  "C:\\zichen\\aquila_mp\\sw\\Coremark\\coremark.elf"
//`define SIM_FNAME_0 "/home/zichen/zichen/aquila_mp/sw/Dhrystone/dhry.elf"
`define SIM_FNAME_0 "/home/zichen/zichen/aquila_mp/sw/test/test_0.elf"
//`define SIM_FNAME_1 "/home/zichen/zichen/aquila_mp/aquila_mp_sw/test/test_1.elf"
//`define SIM_FNAME_1 "/home/zichen/zichen/aquila_mp/sw/coremark_2core/CoreMark2/coremark.elf"
`define SIM_FNAME_1  "/home/zichen/zichen/aquila_mp/sw/test/test_1.elf"
`define SIM_FNAME_2  "/home/zichen/zichen/aquila_mp/sw/test/test_2.elf"
`define SIM_FNAME_3  "/home/zichen/zichen/aquila_mp/sw/test/test_3.elf"