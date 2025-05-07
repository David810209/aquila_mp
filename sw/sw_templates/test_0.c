#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define N 64
#define TIMES 100
#define CORE_NUM 4
volatile unsigned int *print_lock = (unsigned int *)0x80000020U;  

// acquire and release functions for atomic operations
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

// atomic or for synchronization
__attribute__((optimize("O0"))) static void atomic_or(volatile unsigned int *addr, int val) {
    int old = *addr;
    asm volatile (
        "amoor.w %0, %2, %1\n"
        : "=r"(old), "+A"(*addr)
        : "r"(val)
        : "memory"
    );
}   

// semaphore or mutex signal can be used in 0x80000000 - 0x80000FFF
volatile unsigned int *done_init = (unsigned int *)0x80000030U;
volatile unsigned int *done_calc = (unsigned int *)0x80000240U;

int mask = (1 << CORE_NUM) - 1;

int main(){
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    if(hart_id >= CORE_NUM) while(1);
    if (hart_id == 0) 
    {   
        clock_t  tick,ticks_per_msec = CLOCKS_PER_SEC/1000;
        // do some initialization
        //ex: initialize semaphore
        for(int i = 0;i < TIMES;i++){
            done_calc[i] = 0;
        }

        // wait for all cores to finish initialization
        atomic_or(done_init, 1 << hart_id);
        while (*done_init != mask);
        tick = clock();

        // do some calculation
        atomic_or(&done_calc[i], 1 << hart_id);
        while (done_calc[i] != mask);

        tick = (clock() - tick) / ticks_per_msec;
        printf("It took %ld msec to calculation.\n\n", tick);
        exit(0);
    }
    else {
        // wait for all cores to finish initialization
        atomic_or(done_init, 1 << hart_id);
        while (*done_init != mask);
        
        // do some calculation
        atomic_or(&done_calc[i], 1 << hart_id);
        while (done_calc[i] != mask);
        while(1);
    }
    return 0;
}
