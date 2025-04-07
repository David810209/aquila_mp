#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define N 128
#define TIMES 100
#define CORE_NUM 8
volatile unsigned int *print_lock = (unsigned int *)0x80000020U;  

__attribute__((optimize("O0"))) static void atomic_or(volatile unsigned int *addr, int val) {
    int old = *addr;
    asm volatile (
        "amoor.w %0, %2, %1\n"
        : "=r"(old), "+A"(*addr)
        : "r"(val)
        : "memory"
    );
}   

volatile unsigned int *done_init = (unsigned int *)0x80000030U;
volatile unsigned int *A = (unsigned int *)0x80090000U;
volatile unsigned int *B = (unsigned int *)0x80190000U;
volatile unsigned int *C = (unsigned int *)0x80390000U;
volatile unsigned int *ans = (unsigned int *)0x80590000U;
volatile unsigned int *done_memcpy = (unsigned int *)0x80000040U;
volatile unsigned int *done_calc = (unsigned int *)0x80000240U;
volatile unsigned int *done_eval = (unsigned int *)0x80000440U;

int mask = (1 << CORE_NUM) - 1;

void generate_answer() {
    for (int i = 0; i < N; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < N; k++) {
                ans[i * N + j] += A[i * N + k] * B[k * N + j];
            }
        }
    }
}

void matrix_multiply(int core_id) {
    int start_row = core_id * (N / CORE_NUM);
    int end_row = start_row + (N / CORE_NUM);
    for (int i = start_row; i < end_row; i++) {
        for (int j = 0; j < N; j++) {
            for (int k = 0; k < N; k++) {
                C[i * N + j] += A[i * N + k] * B[k * N + j];
            }
        }
    }
}

int main(){
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    if (hart_id == 0) 
    {   
        clock_t  tick,ticks_per_msec = CLOCKS_PER_SEC/1000;

        for(int i = 0; i < N * N; i++){
            A[i] = i;
            B[i] = i;
            ans[i] = 0;
        }
        for(int i = 0;i < TIMES;i++){
            done_calc[i] = 0;
            done_eval[i] = 0;
            done_memcpy[i] = 0;
        }
        generate_answer();
        atomic_or(done_init, 1 << hart_id);
        while (*done_init != mask);
        tick = clock();
        for(int i = 0;i < TIMES;i++){
            for(int j = 0;j < N * N;j++){
                C[j] = 0;
            }
            atomic_or(&done_memcpy[i], 1 << hart_id);
            while (done_memcpy[i] != mask);

            matrix_multiply(hart_id);
            atomic_or(&done_calc[i], 1 << hart_id);
            while (done_calc[i] != mask);
            printf("calculation %d done\n", i);
            for(int j = 0;j < N * N;j++){
                if(C[j] != ans[j]){
                    printf("wrong answer at index %d\n", j);
                    exit(1);
                }
            }

            atomic_or(&done_eval[i], 1 << hart_id);
            while (done_eval[i] != mask);
        }
        tick = (clock() - tick) / ticks_per_msec;
        printf("It took %ld msec to calculation.\n\n", tick);
        exit(0);
    }
    else {
        atomic_or(done_init, 1 << hart_id);
        while (*done_init != mask);
        
        for(int i = 0;i < TIMES;i++){
            atomic_or(&done_memcpy[i], 1 << hart_id);
            while (done_memcpy[i] != mask);

            matrix_multiply(hart_id);

            atomic_or(&done_calc[i], 1 << hart_id);
            while (done_calc[i] != mask);

            atomic_or(&done_eval[i], 1 << hart_id);
            while (done_eval[i] != mask);
        }
        while(1);
    }
    return 0;
}
