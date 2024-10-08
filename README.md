## Aquila MP Project

**Overview**  
This project focuses on verifying and simplifying the coherence circuit design of a dual-core system extended from a RISC-V 5-stage pipelined processor, originally developed by the Embedded Intelligent System Lab. The goal is to expand the architecture to a quad-core system, with real-time testing and validation implemented on the Arty-A7 100T FPGA board.

**Source Code**  
Aquila's source code is available on GitHub: [Aquila GitHub Repository](https://github.com/eisl-nctu/aquila)

**Development Background**  
The dual-core system was originally extended by a senior from the master’s program. The architecture is being further enhanced to accommodate a quad-core system, focusing on optimizing cache coherence and overall system performance.

---

### Current Work

1. **Coherence Verification**  
   - Analyzing hardware code and running CoreMark to trace waveforms and verify the correctness of the cache coherence system design.
   
2. **Shared Memory Testing**  
   - Writing and executing shared memory read/write tests to ensure that the dual-core system can properly handle shared memory operations.

3. **UART Boot Code Modification**  
   - Modifying the UART boot code to fit the Arty A7-100T FPGA board. Originally designed for a more expensive development board, the clock rate is lower, so adjustments to the boot code are necessary.

---

### Future Work

1. **Detailed Documentation**  
   - Writing a detailed block diagram, FSM (Finite State Machine), and timing diagram of the coherence-related unit, followed by adding unit tests for verification.

2. **Simplification of Datapath and Signals**  
   - Simplifying the datapath and signal flow, then verifying that the system still functions correctly under the new design.

3. **Quad-Core Expansion**  
   - Extending the system to a quad-core architecture and testing it with additional benchmarks beyond CoreMark.

---

### Folder and File Descriptions

#### sw/  
- **coremark_2core/** – Test with CoreMark for dual-core performance evaluation  
- **elibc/** – Basic C header library  
- **ocr_1core/** – MLP handwriting recognition evaluation code for single core  
- **ocr_2core/** – Evaluation code for dual core running in parallel  
- **test/** – Shared memory test cases  
- **uartboot/** – Contains both the original and modified UART boot code for the Arty A7-100T board  

#### hw/  
- **aquila_arty/aquila_arty.srcs/** – Source code of the dual-core system
