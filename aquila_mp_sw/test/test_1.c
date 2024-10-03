#include <stdio.h>
volatile unsigned int *print_lock = (unsigned int *)0x80000004U;  

static void setLock(void) {
    asm volatile ("sw x0, 0(%0)" : : "r"(print_lock));  
}

__attribute__((optimize("O0"))) static void acquire(void) {
    asm volatile ("li t0, 1");
    asm volatile ("again:");
    asm volatile ("lw t1, 0(%0)" : : "r"(print_lock));  
    asm volatile ("bnez t1, again");  
    asm volatile ("amoswap.w.aq t1, t0, 0(%0)" : : "r"(print_lock));  
    asm volatile ("bnez t1, again");  
}

__attribute__((optimize("O0"))) static void release(void) {
    asm volatile ("amoswap.w.rl x0, x0, 0(%0)" : : "r"(print_lock)); 
}


#define DONE_0 0x4321
#define DONE_1 0x8765

volatile unsigned int *shared_val = (unsigned int *)0x80000000U;
volatile unsigned int *done_0 = (unsigned int *)0x80000008U;
volatile unsigned int *done_1 = (unsigned int *)0x8000000cU;

int main(){
    *done_1 = 0;
    acquire();
    printf("core1 wait\n");
    release();
    while(*done_0 != DONE_0);
    acquire();
    printf("shared val 1= %d\n", *shared_val);
    release();
    *shared_val = 200;
    *done_1 = DONE_1;

    return 0;
}