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

#include "file_read.h"
#include "neuronet.h"

int main()
{
    NeuroNet nn;
    int n_layers, n_neurons[MAX_LAYERS], class_id;
    int n_images, n_rows, n_cols;
    unsigned correct_count = 0;
    clock_t  tick, ticks_per_msec = CLOCKS_PER_SEC/1000;

    // Read the test images & ground-truth labels.
    printf("\n(1) Reading the test images, labels, and neural weights.\n");
    tick = clock();
    float **images = read_images("test-images.dat", &n_images, &n_rows, &n_cols);
    uint8_t *labels = read_labels("test-labels.dat");
    float *weights = read_weights("weights.dat", &n_layers, n_neurons);
    tick = (clock() - tick)/ticks_per_msec;
    printf("It took %ld msec to read files from the SD card.\n\n", tick);

    // Initialize the neural network model.
    neuronet_init(&nn, n_layers, n_neurons);
    neuronet_load(&nn, weights);

    // Perform hand-written digits recognition tests.
    printf("(2) Perform the hand-written digits recognition test.\n");
    printf("Here, we use a %d-layer %d-%d-%d MLP neural network model.\n",
           n_layers, n_neurons[0], n_neurons[1], n_neurons[2]);
    printf("Begin computing ... ");
    tick = clock();
    for (int idx = 0; idx < n_images; idx++)
    {
        class_id = neuronet_eval(&nn, images[idx]);
        if ((int) labels[idx] == class_id) ++correct_count;
    }
    tick = (clock() - tick)/ticks_per_msec;
    printf("tested %d images. The accuracy is %.2f%%\n\n",
        n_images, 100.0f * (float) correct_count / n_images);
    printf("It took %ld msec to perform the test.\n\n", tick);

    // Free all allocated memory blocks.
    neuronet_free(&nn);
    for (int idx = 0; idx < n_images; idx++) free(images[idx]);
    free(images);
    free(labels);
    free(weights);

    return 0;
}

