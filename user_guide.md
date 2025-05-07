# User Guide

## Build the Hardware

1. Run Vivado in batch mode:
    ```
    /Path/To/Vivado/2024.1/bin/vivado -mode batch -source build_arty100.tcl
    ```
2. Open Vivado's source settings and set the `file_type` of the following files to `SystemVerilog`:
    - `soc_top.v`
    - `soc_tb.v`
    - `amo_arbiter.v`
    - `device_arbiter.v`
    - `coherence_unit.v`

3. Run on FPGA:
    - Generate Bitstream.
    - Open GTKterm and program the device.

4. Run on simulation:
    - Update the `simfile` path in `aquila_config.vh` to match the file path on your computer.
    - Run behavioral simulation.
    - Execute `run --all`.

---

## Software

### 1. OCR
- **Folder**: `./ocr_4core`
- **Simulation**:
  1. Open `file_read.h` and enable `#define DEBUG`.
  2. Run `./build.sh`.
  3. Perform behavioral simulation.
- **On FPGA**:
  1. Comment out `#define DEBUG` in `file_read.h`.
  2. Move `test-lebels.dat`, `test-images-dat`, and `weights.dat` to a micro SD card and insert it into the board.
  3. Run `./build.sh`.
  4. Execute `./send_elf.sh`.

### 2. Matrix Multiply
- **Folder**: `./matrix`
- **Simulation**:
  1. Run `./build.sh`.
  2. Perform behavioral simulation (this may take a long time).
- **On FPGA**:
  1. Adjust `N` and `TIMES`.
  2. Run `./build.sh`.
  3. Execute `./send_elf.sh`.
- **Test Cases**:
  - `N=64, TIMES=100`
  - `N=256, TIMES=1`
- **Note**: If `N` is not a multiple of 4, errors may occur due to lack of write protection on the same cache block..

### 3. array sorting
- **Folder**: `./sorting`
- **Description**: A parallel sorting program that sorts an array of integers using the bubble sort and merge sort algorithm.
- **Simulation**:
  1. Run `./build.sh`.
  2. Perform behavioral simulation.
- **On FPGA**:
  1. Adjust `N`.
  2. Run `./build.sh`.
  3. Execute `./send_elf.sh`.
- **Test Cases**:
  - `N=40000`

### 4. Single-Core CoreMark
- under development

### 5. Writing Test Programs
- Refer to the OCR or Matrix examples to write a multi-core program..
- **Heap and Global Data**:
  - Shared arrays can be declared globally and allocated using `malloc` by one core.
  - Adjust the linker script for larger heaps if needed.
- **Mutex Example**:
```c
  volatile unsigned int *print_lock = (unsigned int *)0x80000020U;
  __attribute__((optimize("O0"))) static void acquire(void) {
        asm volatile ("lui t0, %hi(print_lock)");
        asm volatile ("lw t2, %lo(print_lock)(t0)");
        asm volatile ("li t0, 1");
        asm volatile ("again:");
        asm volatile ("lw t1, (t2)");
        asm volatile
  }
```

semaphore:
```c
int mask = (1 << CORE_NUM) - 1;
volatile unsigned int *done_init = (unsigned int *)0x80000030U;
__attribute__((optimize("O0"))) static void atomic_or(volatile unsigned int *addr, int val) {
    int old = *addr;
    asm volatile (
        "amoor.w %0, %2, %1\n"
        : "=r"(old), "+A"(*addr)
        : "r"(val)
        : "memory"
    );
}   
```

ex:
```c
atomic_or(done_init, 1 << hart_id);
while (*done_init != mask);
```

**Note**: `print_lock` and `done_init` are pre-initialized during the `uartboot` phase to avoid reading undefined memory values during program execution. Currently, there is no better solution for this issue. Therefore, `print_lock` and `done_init` must remain fixed at addresses `0x80000020` and `0x80000030`, respectively.

After the first semaphore operation, additional flags can be freely created for other semaphore implementations.
