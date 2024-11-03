#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <string.h>

#include "file_read.h"
#include "neuronet.h"

// 初始化變數
int hart_id;



int main() {
    hart_id = getID();

    // 初始化所有鎖
    *lock_0 = LOCK_S;
    *lock_1 = LOCK_S;
    setLock();  // 初始化 print_lock

    if (hart_id == 0) {
        initialize();
        acquire();
        printf("\n(1) Reading the test images, labels, and neural weights.\n");
        release();
    }

    // Core 0 讀取 SD 卡
    if (hart_id == 0) {
        tick = clock();

        acquire(); // 進入臨界區
        // 讀取測試影像和真實標籤
        images  = read_images("test-images.dat", &n_images, &n_rows, &n_cols);
        labels  = read_labels("test-labels.dat");
        weights = read_weights("weights.dat", &n_layers, n_neurons);
        release(); // 離開臨界區

        tick = (clock() - tick) / ticks_per_msec;
        acquire();
        printf("It took %ld msec to read files from the SD card.\n\n", tick);
        release();

        // 初始化神經網路模型
        acquire();
        *lock_0 = LOCK_INIT;
        release();

        while (*lock_1 != LOCK_INIT); // 等待核心1初始化完成

        neuronet_init(&nn, n_layers, n_neurons);
        neuronet_load(&nn, weights);

        acquire();
        *lock_0 = LOCK_EVAL;
        release();

        while (*lock_1 != LOCK_EVAL); // 等待核心1進入評估狀態

#ifdef MULT_CORE
        for (int idx = 0; idx < n_images; idx++) {
            neuronet_eval(&nn, images[idx], hart_id);
        }
#endif

        while (*lock_1 != LOCK_DONE);
        
        acquire();
        *lock_0 = LOCK_DONE;
        release();
    } else {
        while (*lock_0 != LOCK_INIT); // 等待核心0進入初始化狀態

        acquire();
        *lock_1 = LOCK_INIT;
        release();

        while (*lock_0 != LOCK_EVAL); // 等待核心0進入評估狀態

        acquire();
        *lock_1 = LOCK_EVAL;
        printf("(2) Perform the hand-written digits recognition test.\n");
        printf("Here, we use a %d-layer %d-%d-%d MLP neural network model.\n",
               n_layers, n_neurons[0], n_neurons[1], n_neurons[2]);
        printf("Begin computing ...\n");
        release();

        tick = clock();

        for (int idx = 0; idx < n_images; idx++) {        
            class_id = neuronet_eval(&nn, images[idx], hart_id);
            if ((int) labels[idx] == class_id) ++correct_count;
#ifdef DEBUG
            acquire();
            printf("%d [correct %d][nn %d]\n", idx, labels[idx], class_id);
            release();
#endif
        }

        tick = (clock() - tick) / ticks_per_msec;

        acquire();
        printf("[Core %d] Tested %d images. The accuracy is %.2f%%\n\n", hart_id,
               n_images, 100.0f * (float) correct_count / n_images);
        printf("It took %ld msec to perform the test.\n\n", tick);
        release();

        // 釋放所有分配的記憶體區塊
        neuronet_free(&nn);
        for (int idx = 0; idx < n_images; idx++) free(images[idx]);
        free(images);
        free(labels);
        free(weights);

        acquire();
        *lock_1 = LOCK_DONE;
        release();

        while (*lock_0 != LOCK_DONE); // 等待核心0完成
    }
    
    return 0;
}
