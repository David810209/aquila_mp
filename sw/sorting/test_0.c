#include <stdio.h>
#include <stdlib.h>
#include <time.h>
#define LENGTH 40000
#define CORE_NUM 8  
#define N (LENGTH / CORE_NUM)
// #define is_one
#define is_two
// #define is_Eight 
// #define is_four
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

volatile unsigned int *done_init   = (unsigned int *)0x80000030U;
volatile unsigned int *done_first  = (unsigned int *)0x80000040U;
volatile unsigned int *done_second = (unsigned int *)0x80000240U;
volatile unsigned int *done_third  = (unsigned int *)0x80000340U;
volatile unsigned int *done_final  = (unsigned int *)0x80000440U;

unsigned int *data;
// unsigned int *check;
unsigned int *original;
unsigned int *temp;

int mask = (1 << CORE_NUM) - 1;

void sort_segment(int start, int end) {
    for (int i = start; i < end; i++) {
        for (int j = start; j < end - (i - start); j++) {
            if (data[j] > data[j + 1]) {
                int tmp = data[j];
                data[j] = data[j + 1];
                data[j + 1] = tmp;
            }
        }
    }
}


void merge_segments(int start1, int end1, int start2, int end2, int dest_start) {
    unsigned int temp[N * CORE_NUM];
    int i = start1, j = start2, k = dest_start;
    for(int i=0;i<N*CORE_NUM;i++){
        temp[i] = 0;
    }

    while (i <= end1 && j <= end2) {
        if (data[i] <= data[j]){
            temp[k] = data[i];
            k++;
            i++;
        }
        else{
            temp[k] = data[j];
            k++;
            j++;
        }
    }

    while (i <= end1){
        temp[k] = data[i];
        k++;
        i++;
    } 

    while (j <= end2) {
        temp[k] = data[j];
        k++;
        j++;
    }

    for (int m = start1; m <= end2; m++) {
        data[m] = temp[m];
    }
}


int is_sorted() {
    for (int i = 1; i < N * CORE_NUM; i++) {
        if (data[i] < data[i - 1]) return 0;
    }
    return 1;
}


void quicksort(unsigned int arr[], int left, int right) {
    if (left >= right) return;

    int i = left, j = right;
    unsigned int pivot = arr[(left + right) / 2];

    while (i <= j) {
        while (arr[i] < pivot) i++;
        while (arr[j] > pivot) j--;
        if (i <= j) {
            unsigned int tmp = arr[i];
            arr[i] = arr[j];
            arr[j] = tmp;
            i++;
            j--;
        }
    }

    if (left < j) quicksort(arr, left, j);
    if (i < right) quicksort(arr, i, right);
}

int main() {
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    if (hart_id >= CORE_NUM) while (1);

    if (hart_id == 0) {
        *done_first = 0;
        *done_second = 0;
        *done_third = 0;
        *done_final = 0;
        clock_t tick, ticks_per_msec = CLOCKS_PER_SEC / 1000;
        tick = clock();
        data     = (unsigned int *)malloc(N * CORE_NUM * sizeof(unsigned int));
        original = (unsigned int *)malloc(N * CORE_NUM * sizeof(unsigned int));

        for (int i = 0; i < N * CORE_NUM; i++) {
            int number = rand() % 10000;
            data[i] = number;
            original[i] = number;
            // printf("%d\n", data[i]);
        }
        printf("\n");

        atomic_or(done_init, 1 << hart_id);
        while (*done_init != mask);

#ifdef is_one
        // first part
        sort_segment(0, N - 1);           
        sort_segment(N, 2 * N - 1);       
        sort_segment(2 * N, 3 * N - 1);   
        sort_segment(3 * N, 4 * N - 1);   
        sort_segment(4 * N, 5 * N - 1);   
        sort_segment(5 * N, 6 * N - 1);   
        sort_segment(6 * N, 7 * N - 1);   
        sort_segment(7 * N, 8 * N - 1);   
        // first merge
        merge_segments(0 * N, 1 * N - 1, 1 * N, 2 * N - 1, 0 * 2 * N);  
        merge_segments(2 * N, 3 * N - 1, 3 * N, 4 * N - 1, 1 * 2 * N);  
        merge_segments(4 * N, 5 * N - 1, 5 * N, 6 * N - 1, 2 * 2 * N);
        merge_segments(6 * N, 7 * N - 1, 7 * N, 8 * N - 1, 3 * 2 * N);
        // second merge
        merge_segments(0, (2 * N - 1), (2 * N), (4 * N - 1), 0);
        merge_segments(4 * N, (6 * N - 1), (6 * N), (8 * N - 1), (4 * N));
        // third merge
        merge_segments(0, (4 * N - 1), (4 * N), (8 * N - 1), 0);

        // atomic_or(done_first, 1 << hart_id);
        // while (*done_first != mask);

        // atomic_or(done_second, 1 << hart_id);
        // while (*done_second != mask);

        // atomic_or(done_third, 1 << hart_id);
        // while (*done_third != mask);

        // atomic_or(done_final, 1 << hart_id);
        // while (*done_final != mask);

#endif
#ifdef is_two
        // first part
        printf("start\n");
        sort_segment(0, N - 1);           
        sort_segment(N, 2 * N - 1);       
        sort_segment(2 * N, 3 * N - 1);   
        sort_segment(3 * N, 4 * N - 1);  
        printf("finish first sort\n");
        atomic_or(done_first, 1 << hart_id);
        while (*done_first != mask);  
        // printf("finish first sort\n");
        // first merge
        merge_segments(0 * N, 1 * N - 1, 1 * N, 2 * N - 1, 0 * 2 * N);  
        merge_segments(2 * N, 3 * N - 1, 3 * N, 4 * N - 1, 1 * 2 * N);
        atomic_or(done_second, 1 << hart_id);
        while (*done_second != mask);  
        // second merge
        merge_segments(0, (2 * N - 1), (2 * N), (4 * N - 1), 0);
        atomic_or(done_third, 1 << hart_id);
        while (*done_third != mask);
        // third merge
        merge_segments(0, (4 * N - 1), (4 * N), (8 * N - 1), 0);
        atomic_or(done_final, 1 << hart_id);
        while (*done_final != mask);
#endif 

#ifdef is_four    
        // first part
        sort_segment(0, N - 1);           
        sort_segment(N, 2 * N - 1); 
        atomic_or(done_first, 1 << hart_id);
        while (*done_first != mask);           
        // first merge
        merge_segments(0, N - 1, N, 2 * N - 1, 0 );  
        atomic_or(done_second, 1 << hart_id);
        while (*done_second != mask);  
        // second merge
        merge_segments(0, (2 * N - 1), (2 * N), (4 * N - 1), 0);
        atomic_or(done_third, 1 << hart_id);
        while (*done_third != mask);
        // third merge
        merge_segments(0, (4 * N - 1), (4 * N), (8 * N - 1), 0);
        atomic_or(done_final, 1 << hart_id);
        while (*done_final != mask);
#endif

#ifdef is_Eight
        // first part
        sort_segment(0, N - 1);    
        atomic_or(done_first, 1 << hart_id);
        while (*done_first != mask);         
        // first merge
        merge_segments(0 * N, 1 * N - 1, 1 * N, 2 * N - 1, 0 * 2 * N);  
        atomic_or(done_second, 1 << hart_id);
        while (*done_second != mask);
        // second merge
        merge_segments(0, (2 * N - 1), (2 * N), (4 * N - 1), 0);
        atomic_or(done_third, 1 << hart_id);
        while (*done_third != mask);
        // third merge
        merge_segments(0, (4 * N - 1), (4 * N), (8 * N - 1), 0);
        atomic_or(done_final, 1 << hart_id);
        while (*done_final != mask);
#endif


        tick = (clock() - tick) / ticks_per_msec;
        printf("It took %ld msec to sort.\n", tick);


        quicksort(original, 0, N * CORE_NUM - 1);
        int correct = 1;
        
        for(int i = 0;i<LENGTH;i++){
            if(original[i] != data[i]){
                printf("the result is wrong\n");
                printf("original[%d] = %d\n", i, original[i]);
                printf("data[%d] = %d\n", i, data[i]);
                correct = 0;
            }
        }
        
        if(correct == 1){
            printf("\nthe result is correct\n");
        }
        
        exit(0);

    } 
    else {
        atomic_or(done_init, 1 << hart_id);
        while (*done_init != mask);

#ifdef is_one
        while(1);
#endif
#ifdef is_two
        if(hart_id == 1){
            sort_segment(4 * N, 5 * N - 1);   
            sort_segment(5 * N, 6 * N - 1);   
            sort_segment(6 * N, 7 * N - 1);   
            sort_segment(7 * N, 8 * N - 1);   
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask);
            // first merge
            merge_segments(4 * N, 5 * N - 1, 5 * N, 6 * N - 1, 2 * 2 * N);
            merge_segments(6 * N, 7 * N - 1, 7 * N, 8 * N - 1, 3 * 2 * N);
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            // second merge
            merge_segments(4 * N, (6 * N - 1), (6 * N), (8 * N - 1), (4 * N));
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
        }
        else{
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask);
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while (1);            
        }
        

#endif

#ifdef is_four 
        // first part
        if(hart_id == 1){
            sort_segment(2 * N, 3 * N - 1);   
            sort_segment(3 * N, 4 * N - 1); 
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask);

            merge_segments(2 * N, 3 * N - 1, 3 * N, 4 * N - 1, 1 * 2 * N); 
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);

            
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);

            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while (1);  
        }
        else if(hart_id == 2){
            sort_segment(4 * N, 5 * N - 1);   
            sort_segment(5 * N, 6 * N - 1);
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask);

            merge_segments(4 * N, 5 * N - 1, 5 * N, 6 * N - 1, 2 * 2 * N);
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);

            merge_segments(4 * N, (6 * N - 1), (6 * N), (8 * N - 1), (4 * N));
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);

            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while (1);  
        }
        else if(hart_id == 3){

            sort_segment(6 * N, 7 * N - 1);
            sort_segment(7 * N, 8 * N - 1);
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask); 

            merge_segments(6 * N, 7 * N - 1, 7 * N, 8 * N - 1, 6 * N);
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask); 

            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);

            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while (1);  
        }
        else{
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask);
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while (1);            
        }

#endif

#ifdef is_Eight
        if(hart_id == 1){
            sort_segment(N, 2 * N - 1); 
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask);      
            merge_segments(2 * N, 3 * N - 1, 3 * N, 4 * N - 1, 1 * 2 * N); 
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            merge_segments(4 * N, (6 * N - 1), (6 * N), (8 * N - 1), (4 * N));
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
            
        }
        else if(hart_id == 2){
            sort_segment(2 * N, 3 * N - 1);   
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask);
            merge_segments(4 * N, 5 * N - 1, 5 * N, 6 * N - 1, 2 * 2 * N);
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
        }
        else if(hart_id == 3){ 
            sort_segment(3 * N, 4 * N - 1);  
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask); 
            merge_segments(6 * N, 7 * N - 1, 7 * N, 8 * N - 1, 3 * 2 * N);
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
        }
        else if(hart_id == 4){
            sort_segment(4 * N, 5 * N - 1);  
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask); 
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
        }
        else if(hart_id == 5){
            sort_segment(5 * N, 6 * N - 1);  
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask); 
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
        }
        else if(hart_id == 6){
            sort_segment(6 * N, 7 * N - 1);  
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask); 
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
        }
        else if(hart_id == 7){
            sort_segment(7 * N, 8 * N - 1);
            atomic_or(done_first, 1 << hart_id);
            while (*done_first != mask); 
            atomic_or(done_second, 1 << hart_id);
            while (*done_second != mask);
            atomic_or(done_third, 1 << hart_id);
            while (*done_third != mask);
            atomic_or(done_final, 1 << hart_id);
            while (*done_final != mask);
            while(1);
        }
#endif

    }
    
    return 0;
}

// atomic_or(done_final, 1 << hart_id);
// while (*done_final != mask);