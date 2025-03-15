#include <stdio.h>
#include <stdlib.h>
#define N 16
volatile unsigned int *print_lock = (unsigned int *)0x80000020U;  

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

volatile unsigned int *done = (unsigned int *)0x80000030U;
volatile unsigned int *A = (unsigned int *)0x80090000U;
volatile unsigned int *B = (unsigned int *)0x800a0000U;
volatile unsigned int *C = (unsigned int *)0x800b0000U;

void matrix_multiply(int core_id) {
    int start_row = core_id * (N / 4);
    int end_row = start_row + (N / 4);
    for (int i = start_row; i < end_row; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < N; k++) {
                C[i * N + j] += A[i * N + k] * B[k * N + j];
            }
        }
    }
}

int main(){
    done[0] = 0;
    done[1] = 0;
    done[2] = 0;
    done[3] = 0;
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    setLock();
    if (hart_id == 0) 
    {   
        acquire();
        for(int i = 0; i < N * N; i++){
            A[i] = i;
            B[i] = i;
            C[i] = 0;
        }
        printf("core0 finish initialize\n");
        done[0] = 1;
        release();
        matrix_multiply(0);
        while(done[1] == 0 || done[2] == 0 || done[3] == 0);
        acquire();
        printf("core0: Matrix multiplication result:\n");
        for (int i = 0; i < N; i++) {
            for (int j = 0; j < N; j++) {
                printf("%d ", C[i * N + j]);
            }
            printf("\n");
        }
        release();
        exit(0);
    }
    else{
        while(done[0] == 0);
        matrix_multiply(hart_id);
        done[hart_id] = 1;
        while(1);
    }
 

    return 0;
}