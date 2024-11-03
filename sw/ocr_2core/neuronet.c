// =============================================================================
//  Program : neuronet.c
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

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <time.h>

#include "neuronet.h"

/* For 2-Core */
unsigned int print_lock = 0x80000004U;;
volatile unsigned int *lock_0 = (unsigned int *)0x80000020U;
volatile unsigned int *lock_1 = (unsigned int *)0x80000040U;

NeuroNet nn;
int n_layers, n_neurons[MAX_LAYERS], class_id;
int n_images, n_rows, n_cols;
unsigned correct_count;
clock_t  tick, ticks_per_msec;

float **images = NULL; 
uint8_t *labels = NULL;
float *weights = NULL; 

void initialize() {
    correct_count = 0;
    ticks_per_msec = CLOCKS_PER_SEC/1000;
}

int getID() {
    int hart_id;
    asm volatile ("csrrs %0, mhartid, x0" :"=r"(hart_id): : );
    return hart_id;
}

void setLock(void) {
    asm volatile ("lui t0, %hi(print_lock)");
    asm volatile ("lw t2, %lo(print_lock)(t0)");
    asm volatile ("sw x0, (t2)");
}

__attribute__((optimize("O0")))  void acquire(void) {
    asm volatile ("lui t0, %hi(print_lock)");
    asm volatile ("lw t2, %lo(print_lock)(t0)");
    asm volatile ("li t0, 1");
    asm volatile ("again:");
    asm volatile ("lw t1, (t2)"); // [t2] initial value is zero.
    asm volatile ("bnez t1, again"); // if [t1] isn't zero , jumo to "again" 
    asm volatile ("amoswap.w.aq t1, t0, (t2)");
    asm volatile ("bnez t1, again");
}

__attribute__((optimize("O0"))) void release(void) {
    asm volatile ("lui t0, %hi(print_lock)");
    asm volatile ("lw t2, %lo(print_lock)(t0)");
    asm volatile ("amoswap.w.rl x0, x0, (t2)");
}

/* nn */
void neuronet_init(NeuroNet *nn, int n_layers, int *n_neurons)
{
    int layer_idx, neuron_idx, sum;
    float *head[MAX_LAYERS];  // Pointer to the first neuron value of each layer.

    if (n_layers < 2 || n_layers > MAX_LAYERS)
    {
        printf("ERROR!!!\n");
        printf("layer count is less than 2 or larger than %d\n", MAX_LAYERS);
        return;
    }

    nn->total_neurons = 0;
    
    for (layer_idx = 0; layer_idx < n_layers; layer_idx++)
    {
        nn->n_neurons[layer_idx] = n_neurons[layer_idx];
        nn->total_neurons += n_neurons[layer_idx];
    }

    nn->neurons = (float *) malloc(sizeof(float *) * nn->total_neurons);
    nn->forward_weights = (float **) malloc(sizeof(float *) * nn->total_neurons);
    nn->previous_neurons = (float **) malloc(sizeof(float *) * nn->total_neurons);
    nn->total_layers = n_layers;

    neuron_idx = 0;
    for (layer_idx = 0; layer_idx < nn->total_layers; layer_idx++)
    {
        head[layer_idx] = &(nn->neurons[neuron_idx]);
        neuron_idx += nn->n_neurons[layer_idx];
    }

    // Set a shortcut pointer to the output layer neuron values.
    nn->output = head[nn->total_layers - 1];

    // Set the previous layer neuron pointers for each hidden & output neuron
    for (neuron_idx = nn->n_neurons[0], layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {
        for (unsigned j = 0; j < nn->n_neurons[layer_idx]; ++j, ++neuron_idx)
        {
            nn->previous_neurons[neuron_idx] = head[layer_idx - 1];
        }
    }

    // Initialize the weight array.
    nn->total_weights = 0;
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {
        // Accumulating # of weights, including one bias value per neuron.
        nn->total_weights += (nn->n_neurons[layer_idx-1] + 1)*nn->n_neurons[layer_idx];
    }
    nn->weights = (float *) malloc(sizeof(float) * nn->total_weights);

    // Set the starting pointer to the forward weights for each neurons.
    sum = 0, neuron_idx = nn->n_neurons[0];
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++)
    {
        for (int idx = 0; idx < nn->n_neurons[layer_idx]; idx++, neuron_idx++)
        {
            nn->forward_weights[neuron_idx] = &(nn->weights[sum]);
            sum += (nn->n_neurons[layer_idx-1] + 1); // add one for bias.
        }
    }
}

void neuronet_load(NeuroNet *nn, float *weights)
{   
    for (int idx = 0; idx < nn->total_weights; idx++)
    {
        nn->weights[idx] = *(weights++);   
    }
    return;
}

void neuronet_free(NeuroNet *nn)
{
    free(nn->weights);
    free(nn->previous_neurons);
    free(nn->forward_weights);
    free(nn->neurons);
}

int neuronet_eval(NeuroNet *nn, float *images, int hart_id)
{
            // 重置锁的状态
    acquire();
    if(*lock_0 != LOCK_INITIAL)*lock_0 = LOCK_INITIAL;
    if(*lock_1 != LOCK_INITIAL)*lock_1 = LOCK_INITIAL;
    release();
    hart_id = getID();
    float inner_product, max;
    float *p_neuron, *p_weight;
    int idx, layer_idx, neuron_idx, max_idx;

#ifdef MULT_CORE
    if(hart_id == 0){
        while (*lock_1 != LOCK_EVAL_MEMCPY) ;

        acquire();
        *lock_0 = LOCK_EVAL_MEMCPY; 
        printf("core 0 enter eval\n");
        release();
    }
    else{
        // Copy the input image array (784 pixels) to the input neurons.
        acquire();
        memcpy((void *) nn->neurons, (void *) images, nn->n_neurons[0]*sizeof(float));
        *lock_1 = LOCK_EVAL_MEMCPY;
        printf("core 1 enter eval\n");
        release();
        while (*lock_0 != LOCK_EVAL_MEMCPY);
    }
    
    // Forward computations 
    neuron_idx = nn->n_neurons[0];
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++){
        for (idx = 0; idx < nn->n_neurons[layer_idx] / 2; idx++){
            // 'p_weight' points to the first forward weight of a layer.
            p_weight = nn->forward_weights[neuron_idx + hart_id];
            p_neuron = nn->previous_neurons[neuron_idx + hart_id];
            
            inner_product = 0.0;

            // Loop over all forward-connected neural links.

            for (int jdx = 0; jdx < nn->n_neurons[layer_idx-1]; jdx++){
                inner_product += (*p_neuron++) * (*p_weight++);
            }
            inner_product += *(p_weight); // The last weight of a neuron is the bias.
            nn->neurons[neuron_idx + hart_id] = relu(inner_product);
            neuron_idx = neuron_idx + 2;
#ifdef DEBUG
            acquire();
            printf("[core %d] %f\n", hart_id, inner_product);
            release();
#endif
            /*for (int i = 0; i < 5 ; i++) {
                __asm__ volatile ("nop");
            }*/
        }
    }
    // Return the index to the maximal neuron value of the output layer.
    if(hart_id == 0){
        while (*lock_1 != LOCK_EVAL_INNPROC);
        acquire();
        *lock_0 = LOCK_EVAL_INNPROC;    
        release();
        return 0; 
    } 
    else{
        acquire();
        *lock_1 = LOCK_EVAL_INNPROC; 
        release();
        while (*lock_0 != LOCK_EVAL_INNPROC);
        max = -1.0, max_idx = 0;
        for (idx = 0; idx < nn->n_neurons[nn->total_layers-1]; idx++)
        {
            if (max < nn->output[idx])
            {
                max_idx = idx;
                max = nn->output[idx];      
            }  
        }
        return max_idx;   
    } 
    
#else   
    memcpy((void *) nn->neurons, (void *) images, nn->n_neurons[0]*sizeof(float));        
    // Forward computations
    neuron_idx = nn->n_neurons[0];
    for (layer_idx = 1; layer_idx < nn->total_layers; layer_idx++){
        for (idx = 0; idx < nn->n_neurons[layer_idx]; idx++){
            // 'p_weight' points to the first forward weight of a layer.
            p_weight = nn->forward_weights[neuron_idx];
            p_neuron = nn->previous_neurons[neuron_idx];
            inner_product = 0.0;

            // Loop over all forward-connected neural links.

            for (int jdx = 0; jdx < nn->n_neurons[layer_idx-1]; jdx++)
            {
                inner_product += (*p_neuron++) * (*p_weight++);
            }
            inner_product += *(p_weight); // The last weight of a neuron is the bias.
            nn->neurons[neuron_idx] = relu(inner_product);
            acquire();
            printf("%f %f\n", inner_product, nn->neurons[neuron_idx + hart_id]);
            release();
            neuron_idx = neuron_idx + 1;    
        }
    }
    // Return the index to the maximal neuron value of the output layer.
    max = -1.0, max_idx = 0;
    for (idx = 0; idx < nn->n_neurons[nn->total_layers-1]; idx++)
    {
        if (max < nn->output[idx])
        {
            max_idx = idx;
            max = nn->output[idx];      
        }  
    }
    return max_idx;
#endif          
}

float relu(float x)
{
	return x < 0.0 ? 0.0 : x;
}
