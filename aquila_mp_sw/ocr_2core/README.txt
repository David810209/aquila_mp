# OCR for Dual-Core Execution

This document describes OCR execution in a dual-core system.


## File Information
1. file_read.h/neuronet.h: `#define DEBUG` is used for simulation purposes.
2. file_read.c: Under `#ifdef DEBUG`, you need to manually provide image, label, and weight data.


## Build and Execution

* Simulation
1. Run build.sh: Used to build two ELF files.
2. Place the paths of the ELF files into SIM_FNAME_0 and SIM_FNAME_1 in aquila_config.vh.

* On FPGA
1. Run build.sh: Used to build two ELF files.
2. Run send_elf.sh: Sends the two ELF files via UART.