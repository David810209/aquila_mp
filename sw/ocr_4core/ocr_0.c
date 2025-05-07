#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <string.h>

#include "file_read.h"
#include "neuronet.h"

int main() {
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    if(hart_id >= CORE_NUM) while(1);
    if (hart_id == 0) {
        initialize();
        for(int i = 0;i < 100;i++){
            done_calc[i] = 0;
            done_eval[i] = 0;
            done_memcpy[i] = 0;
        }
        // acquire();
        printf("\n(1) Reading the test images, labels, and neural weights.\n");
        // release();

        // Core 0 讀取 SD 卡
        tick = clock();

        // 讀取測試影像和真實標籤
        images  = read_images("test-images.dat", &n_images, &n_rows, &n_cols);
        labels  = read_labels("test-labels.dat");
        weights = read_weights("weights.dat", &n_layers, n_neurons);

        tick = (clock() - tick) / ticks_per_msec;
        printf("It took %ld msec to read files from the SD card.\n\n", tick);
        neuronet_init(&nn, n_layers, n_neurons);
        neuronet_load(&nn, weights);
    }
    atomic_or(done_init, 1 << hart_id);
    while (*done_init != mask);

    if(hart_id == 0) {
        printf("(2) Perform the hand-written digits recognition test.\n");
        printf("Here, we use a %d-layer %d-%d-%d MLP neural network model.\n",
               n_layers, n_neurons[0], n_neurons[1], n_neurons[2]);
        printf("Begin computing ...\n");
        tick = clock();
        for (int idx = 0; idx < n_images; idx++) {
            // if(idx < 10){
                //  printf("%d start\n", idx);
            // }
            class_id = neuronet_eval(&nn, images[idx], hart_id, idx);
            if ((int) labels[idx] == class_id) ++correct_count;
            // if(idx < 10){
                 printf("%d finish\n", idx);
            // }
        }
        tick = (clock() - tick) / ticks_per_msec;

        printf("[Core %d] Tested %d images. The accuracy is %.2f%%\n\n", hart_id,
               n_images, 100.0f * (float) correct_count / n_images);
        printf("It took %ld msec to perform the test.\n\n", tick);

        // 釋放所有分配的記憶體區塊
        neuronet_free(&nn);
        for (int idx = 0; idx < n_images; idx++) free(images[idx]);
        free(images);
        free(labels);
        free(weights);

        exit(0);
    } 
    
    else  {

        for (int idx = 0; idx < n_images; idx++) {        
            neuronet_eval(&nn, images[idx], hart_id, idx);
        }
        while(1);
    }
    return 0;
}
