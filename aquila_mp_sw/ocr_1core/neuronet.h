// =============================================================================
//  Program : neuronet.h
//  Author  : Chun-Jen Tsai
//  Date    : Dec/06/2023
// -----------------------------------------------------------------------------
//  Description:
//      This is a neural network library that can be used to implement
//  a inferencing model of the classical multilayer perceptorn (MLP) neural
//  network. It reads a model weights file to setup the MLP. The MLP
//  can have up to MAX_LAYERS, which is defined in neuronet.h. To avoid using
//  the C math library, the relu() fucntion is used for the activation
//  function. This degrades the recognition accuracy significantly, but it
//  serves the teaching purposes well.
//
//  This program is designed as one of the homework projects for the course:
//  Microprocessor Systems: Principles and Implementation
//  Dept. of CS, NYCU (aka NCTU), Hsinchu, Taiwan.
// -----------------------------------------------------------------------------
//  Revision information:
//
//  None.
// =============================================================================

#define MAX_LAYERS 8

typedef struct __NeuroNet
{
    float *neurons;             // Array that stores all the neuron values.
    float *weights;             // Array that store all the weights & biases.

    float **previous_neurons;   // Pointers to the previous-layer neurons.
    float **forward_weights;    // Pointers to the weights & bias.

    int n_neurons[MAX_LAYERS];  // The # of neurons in each layer.
    int total_layers;           // The total # of layers.
    int total_neurons;          // The total # of neurons.
    int total_weights;          // The total # of weights.
    float *output;              // Pointer to the neurons of the output layer.
} NeuroNet;

void neuronet_init(NeuroNet *nn, int n_layers, int *n_neurons);
void neuronet_load(NeuroNet *nn, float *weights);
void neuronet_free(NeuroNet *nn);
int  neuronet_eval(NeuroNet *nn, float *images);
float relu(float x);

