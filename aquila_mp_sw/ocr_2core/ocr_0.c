// =============================================================================
//  Program : ocr.c
//  Author  : Chun-Jen Tsai
//  Date    : Dec/06/2023
// -----------------------------------------------------------------------------
//  Description:
//      This program uses the classical multilayer perceptorn (MLP) neural network
//  for hand-written digits recognition. It reads a model weights file to setup
//  the MLP neural network. The model weights are trained with the famous MNIST
//  dataset. To avoid using the C math library, the relu() fucntion is used for
//  the activation function. This degrades the accuracy significantly, but it
//  serves our purpose well.
//
//  This program is designed as one of the homework projects for the course:
//  Microprocessor Systems: Principles and Implementation
//  Dept. of CS, NYCU (aka NCTU), Hsinchu, Taiwan.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// =============================================================================

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <time.h>
#include <string.h>

#include "file_read.h"
#include "neuronet.h"

int main()
{
    acquire();
    printf("enter_0\n");
    release();
    int hart_id = getID();
    
    *lock_0 = LOCK_S;
    *lock_1 = LOCK_S;
    
    if(hart_id == 0){
        initialize();
        acquire();
        printf("\n(1) Reading the test images, labels, and neural weights.\n");
        release();
    }
    

    // Core 0 read sd card
    if(hart_id == 0){
        tick = clock();
        // Read the test images & ground-truth labels.
        images  = read_images("test-images.dat", &n_images, &n_rows, &n_cols);
        labels  = read_labels("test-labels.dat");
        weights = read_weights("weights.dat", &n_layers, n_neurons);
        
        tick = (clock() - tick)/ticks_per_msec;
        acquire();
        printf("It took %ld msec to read files from the SD card.\n\n", tick);
        release();
        // Initialize the neural network model.
        
        *lock_0 = LOCK_INIT;
        while (*lock_1 != LOCK_INIT);
        
        neuronet_init(&nn, n_layers, n_neurons);
        neuronet_load(&nn, weights);
        *lock_0 = LOCK_EVAL;
        while (*lock_1 != LOCK_EVAL);
        for (int idx = 0; idx < n_images ; idx++)
        {
#ifdef MULT_CORE
            neuronet_eval(&nn, images[idx], hart_id);
#endif
        }
        
        while (*lock_1 != LOCK_DONE);
        *lock_0 = LOCK_DONE; 
    }
    else{
        while (*lock_0 != LOCK_INIT);
        *lock_1 = LOCK_INIT; 

        while (*lock_0 != LOCK_EVAL);
        *lock_1 = LOCK_EVAL;

        acquire();
        printf("(2) Perform the hand-written digits recognition test.\n");
        printf("Here, we use a %d-layer %d-%d-%d MLP neural network model.\n",
               n_layers, n_neurons[0], n_neurons[1], n_neurons[2]);
        printf("Begin computing ...\n");
        release();
        tick = clock();
        
        for (int idx = 0; idx < n_images ; idx++)
        {        
            class_id = neuronet_eval(&nn, images[idx], hart_id);
            if ((int) labels[idx] == class_id) ++correct_count;
#ifdef DEBUG
            acquire();
            printf("%d [correct %d][nn %d]\n", idx, labels[idx], class_id);
            release();
#endif
        }
        tick = (clock() - tick)/ticks_per_msec;
        acquire();
        printf("[Core %d] Tested %d images. The accuracy is %.2f%%\n\n", hart_id,
           n_images, 100.0f * (float) correct_count / n_images);
        printf("It took %ld msec to perform the test.\n\n", tick);
        release();
        // Free all allocated memory blocks.
        neuronet_free(&nn);
        for (int idx = 0; idx < n_images; idx++) free(images[idx]);
        free(images);
        free(labels);
        free(weights);
        
        *lock_1 = LOCK_DONE;
        while (*lock_0 != LOCK_DONE);
    }
    return 0;
}

