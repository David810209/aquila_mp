### 9/26 Makefile Modification Log:

#### /elibc:
- **crt0.c**:
  - Refactored the file to retain only the `core0`-related initialization code.
  
- **crt1.c**:
  - Created a new file containing only the `core1`-related initialization code, separating it from `crt0.c`.
  
- **Makefile**:
  - Updated object file dependencies to include `crt1.o` for `core1` initialization:
    ```diff
    - LIBC_OBJS = $(LIBC)/crt0.o  $(LIBC)/stdio.o $(LIBC)/stdlib.o $(LIBC)/string.o $(LIBC)/time.o $(LIBC)/uart.o
    + LIBC_OBJS = $(LIBC)/crt0.o  $(LIBC)/crt1.o  $(LIBC)/stdio.o $(LIBC)/stdlib.o $(LIBC)/string.o $(LIBC)/time.o $(LIBC)/uart.o
    ```

#### /ocr_2core:
- **ocr_1.ld**:
  - Modified the linker script to set `crt1` as the entry point for `core1`.
  
- **Makefile**:
  - Adjusted the object file list to include `crt1.o` for `core1` support:
    ```diff
    - LIBC_OBJS = $(LIBC)/crt0.o  $(LIBC)/stdio.o $(LIBC)/stdlib.o $(LIBC)/string.o $(LIBC)/time.o $(LIBC)/uart.o
    + LIBC_OBJS = $(LIBC)/crt0.o  $(LIBC)/crt1.o  $(LIBC)/stdio.o $(LIBC)/stdlib.o $(LIBC)/string.o $(LIBC)/time.o $(LIBC)/uart.o
    ```

#### /uartboot:
- **uartboot.c**:
  - Modified to run an infinite loop (`while (1) {}`) only when `mhard_id == 1`.
  - Removed the locking mechanism, simplifying the logic for `core1`.
