# The Aquila Quad-Core RISC-V SoC

---

Aquila-Quad is an open-source quad-core system-on-chip featuring a 32-bit RISC-V RV32IMA processor, extended by the [Aquila SoC](https://github.com/eisl-nctu/aquila). It employs the MESI cache coherence protocol to maintain data consistency across L1 and L2 caches in a shared memory system. The processor supports atomic instructions for efficient synchronization and mutual exclusion in multicore environments. Developed using Verilog HDL, the system is synthesized with the Xilinx Vivado toolchain and operates on the Arty A7-100T FPGA board.

![Architecture Diagram](architecture.jpg)

---

## **Specification**

Current features of the Aquila-Quad SoC include:

- RV32IMA ISA-compliant.
- Embedded 16KB tightly-coupled on-chip memory (TCM).
- 8KB L1 data and instruction caches.
- 64KB L2 cache shared among four cores.
- Multi-core support with coherent data cache controller.
- CLINT for standard timer interrupts.
- The RTL model written in Verilog.
- SD card I/O support.

---

## **Performance**
Performance is evaluated using an MLP-based MNIST handwritten digit recognition task and a parallel matrix multiplication task, achieving 3.65x and 9.25x speed-ups, respectively, compared to the original Aquila SoC. Aquila-Quad delivers 2.01 CoreMark/MHz and 0.86 DMIPS/MHz per core and runs at 50 MHz on a Xilinx Artix-7 FPGA.

## **MESI FSM Diagram**  
The MESI protocol's FSM is visualized below:  

![MESI FSM Diagram](MESI.jpg)

---

## **User's Guide**
The Aquila-Quad SoC is still under development. The user's guild will be updated soon.

---

## **Acknowledgment**  
Aquila's source code is available on GitHub: [Aquila GitHub Repository](https://github.com/eisl-nctu/aquila)

The quad-core system is extended by contributions from the Embedded Intelligent Systems Laboratory (EISL) at National Chiao Tung University (NCTU). We acknowledge the support and collaboration from the open-source community and our academic partners.

## **Current Work**
Integration of a Memory Management Unit (MMU) to enable Linux OS support.
---

## **Folder and File Descriptions**

### **sw/**  
- **elibc/** – Basic C header library  
- **ocr_1core/** – MLP handwriting recognition evaluation code for single core  
- **ocr_4core/** – Evaluation code for quad-core running in parallel  
- **test/** – Matrix multiplication evaluation code for quad-core
- **uartboot/** – Contains both the original and modified UART boot code for the Arty A7-100T board  

### **src/**  
- **mem/** – Contains the uartboot code that can be compiled in `sw/uartboot`
- **soc_rtl/** – Contains the top-level RTL code for the Aquila SoC  
### **build_arty100.tcl**
- Script to build the Aquila-Quad SoC on the Arty A7-100T board
