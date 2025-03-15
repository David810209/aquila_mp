#include <stdio.h>
#define N 256
int main() {
    int a[N * N], b[N * N], c[N * N] = {0}; // 初始化 c 為 0

    // 初始化 a 和 b，讓它們都是 4x4 矩陣
    for (int i = 0; i < N * N; i++) {
        a[i] = i % 3;
        b[i] = (i + 2) % 5;
        c[i] = 0;
    }

    // 進行矩陣乘法：C = A * B
    for (int i = 0; i < N; i++) {        // 行
        for (int j = 0; j < N; j++) {    // 列
            for (int k = 0; k < N; k++) {
                c[i * N + j] += a[i * N + k] * b[k * N + j]; // 矩陣乘法公式
                if(i == 0 && j == 0) printf("a[%d][%d] = %d, b[%d][%d] = %d, c[%d][%d] = %d\n", i, k, a[i * N + k], k, j, b[k * N + j], i, j, c[i * N + j]);
            }
        }
    }
    // // 印出矩陣 A
    // printf("Matrix A:\n");
    // for (int i = 0; i < N; i++) {
    //     for (int j = 0; j < N; j++) {
    //         printf("%d ", a[i * N + j]);
    //     }
    //     printf("\n");
    // }

    // // 印出矩陣 B
    // printf("Matrix B:\n");
    // for (int i = 0; i < N; i++) {
    //     for (int j = 0; j < N; j++) {
    //         printf("%d ", b[i * N + j]);
    //     }
    //     printf("\n");
    // }
    // // 印出結果
    // printf("Matrix C (A * B):\n");
    // for (int i = 0; i < N; i++) {
    //     for (int j = 0; j < N; j++) {
    //         printf("%3d ", c[i * N + j]);
    //     }
    //     printf("\n");
    // }

    return 0;
}
