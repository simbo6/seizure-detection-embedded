//#include "rtc.h"
//#include "stm32f429xx.h"
#include <complex.h>
#include <string.h>
#include <math.h>
//#include "sdio_sdcard.h"
//#include "ff.h"
//#include "exfuns.h"
#define EPIL_PWELCH_FFT_LEN_256 256
#define EPIL_PWELCH_FFT_LEN_1024 1024
#define EPIL_PWELCH_FFT_LEN_MAX EPIL_PWELCH_FFT_LEN_1024
#define EPIL_PWELCH_MAG_LEN_MAX (EPIL_PWELCH_FFT_LEN_MAX / 2)

#ifndef EPIL_PC_BUILD
#include "arm_math.h"

/* ACC/GYR 窗口补零到 256 点，较长窗口补零到 1024 点。 */
static float g_pwelch_fft_input[EPIL_PWELCH_FFT_LEN_MAX];
static float g_pwelch_fft_output[EPIL_PWELCH_FFT_LEN_MAX];
static float g_pwelch_fft_magnitude[EPIL_PWELCH_MAG_LEN_MAX];
static arm_rfft_fast_instance_f32 g_pwelch_fft_instance;
static int g_pwelch_fft_ready = 0;
static int g_pwelch_fft_len = 0;

static int pwelch_prepare_fft(int fft_len)
{
    if (!g_pwelch_fft_ready || g_pwelch_fft_len != fft_len) {
        if (arm_rfft_fast_init_f32(&g_pwelch_fft_instance, fft_len) != ARM_MATH_SUCCESS) {
            return 0;
        }
        g_pwelch_fft_ready = 1;
        g_pwelch_fft_len = fft_len;
    }
    return 1;
}
#endif
#include "sd_card.h"
#include "epil_porting.h"

#define M_PI 3.14159265358979323846





/*
* 函数名称：DFT。
* 函数功能：对不定长的数组进行时频域的变换，将时域信号转变为频域信号。
* 输入参数：x -- 输入数据指针，指针变量，double*。
*       len_x -- x的元素数目，标量，int。
*           X -- 傅里叶变换结果指针（函数结果），指针变量，double*。
*       len_X -- X的元素数目，标量，int。在函数外定义时，X长度为len_x / 2 + 1。
* 返回值：无。
*/
void DFT(const double *x, const int len_x, double complex *X, const int len_X)
{
    // 函数使用的频域变换函数为离散傅里叶变换，如果傅里叶变换（FFT）函数不需要补0的话，换成FFT会更快
    // 不知道嵌入端的mcu里的dsp是否有优化好的FFT函数？

    // 设置中间变量
    int k, n;
    double complex W;

    // 初始化X为全0
    memset(X, 0, len_X * sizeof(double complex));
    // 基于双重循环计算其频域值
    for (k = 0; k < len_X; k++)
    {
        for (n = 0; n < len_x; n++)
        {
            // 欧拉公式，可以根据公式直接把所有W嵌入到程序里，但是要匹配所有使用的情况
            W = cexp(-I * 2 * M_PI * k * n / len_x);
            // 根据全部点进行频域求和
            X[k] += x[n] * W;
        }
    }
}

/*
* 函数名称：pwelch。
* 函数功能：对不定长的数组提取功率谱以及相应频率。
* 输入参数：x -- 输入数据指针，指针变量，double*。
*       len_x -- x的元素数目，标量，int。
*      slideN -- 进行傅里叶变换时窗口的滑动长度，标量，int。
*        winN -- 进行傅里叶变换时的窗口长度，标量，int。
*          fs -- x的采样率，标量，double。
*           P -- 输出的功率谱数据指针，指针变量，double*。
*           f -- 输出的频率指针，指针变量，double*。
*       len_p -- P、f、X数组的长度，标量，int。此长度的计算公式为：len_p = winN / 2 + 1;
* 返回值：无。
*/
#ifdef EPIL_PC_BUILD
static void pc_fft_inplace(double complex *a, int n) {
    for (int i = 1, j = 0; i < n; ++i) {
        int bit = n >> 1;
        for (; j & bit; bit >>= 1) {
            j ^= bit;
        }
        j ^= bit;
        if (i < j) {
            double complex tmp = a[i];
            a[i] = a[j];
            a[j] = tmp;
        }
    }

    for (int len = 2; len <= n; len <<= 1) {
        double angle = -2.0 * M_PI / len;
        double complex wlen = cos(angle) + I * sin(angle);
        for (int i = 0; i < n; i += len) {
            double complex w = 1.0 + 0.0 * I;
            for (int j = 0; j < len / 2; ++j) {
                double complex u = a[i + j];
                double complex v = a[i + j + len / 2] * w;
                a[i + j] = u + v;
                a[i + j + len / 2] = u - v;
                w *= wlen;
            }
        }
    }
}

static void pc_rfft_mag(const double *x, int len_x, int fft_len, double complex *X, int len_X) {
    double complex buf[fft_len];

    for (int i = 0; i < fft_len; ++i) {
        buf[i] = (i < len_x ? x[i] : 0.0) + 0.0 * I;
    }

    pc_fft_inplace(buf, fft_len);

    for (int i = 0; i < len_X; ++i) {
        X[i] = cabs(buf[i]) + 0.0 * I;
    }
}
#endif
void pwelch(const double *x, const int len_x, const int slideN, const int winN, const double fs, double *P,

            const int len_p)
{
    // 时间统计
    unsigned char hour, min, sec, ampm;
    unsigned short ms;

    // 这里理论上还需要有个输入的窗参数：double *window，不过因为是矩形窗，数值都是1，就直接在函数里固定了。

    // 设置参数，如窗口个数（K）、窗口缓存数据（xi）、中间频域结果（X）、用于循环的j、n。
    // 基于窗口计算得到的U被省略。

    int K = (len_x - winN) / slideN + 1;
    // double U = 0;
    int j, n;
#ifdef EPIL_PC_BUILD
    double xi[winN];
#endif
    // double *w = window;
    double complex X[len_p];
    int xi_input_len = (winN <= EPIL_PWELCH_FFT_LEN_256) ?
                       EPIL_PWELCH_FFT_LEN_256 : EPIL_PWELCH_FFT_LEN_1024;
#if 0

	float   xi_input_arr[4096];
	float   xout_temp_arr[4096];
	float   xout_arr[2048];

	memset(xi_input_arr, 0, sizeof(xi_input_arr));
	memset(xout_temp_arr, 0, sizeof(xout_temp_arr));
	memset(xout_arr, 0, sizeof(xout_arr));
#endif	

    /*
    // 计算U的值
    for (n = 0; n < winN; n++) {
        U += pow(w[n], 2);
    }
    U /= winN;
    */

    // 初始化P为全0         很重要的一步
    memset(P, 0, len_p * sizeof(double));

#ifndef EPIL_PC_BUILD
    if (xi_input_len > EPIL_PWELCH_FFT_LEN_MAX ||
        len_p - 1 > xi_input_len / 2 ||
        !pwelch_prepare_fft(xi_input_len)) {
        return;
    }
#endif
		
		// 便于打印
		int fft_cnt = 1;

    // 计算P值
    for (j = 0; j < K; j++)
    {
#ifdef EPIL_PC_BUILD
        // PC 版本使用本地 double 缓冲区执行参考 FFT。
        for (n = 0; n < winN; n++)
        {
            xi[n] = x[j * slideN + n];
            // xi[n] *= w[n];
        }
        pc_rfft_mag(xi, winN, xi_input_len, X, len_p - 1);
        X[len_p - 1] = 0.0;
#else
//////// rfft ////////////////////////////////////////////
        // 将当前窗口直接转换到可复用的 CMSIS FFT 输入缓冲区，并完成补零。
        for (int xi_idx = 0; xi_idx < xi_input_len; xi_idx++)
        {
            if (xi_idx < winN)
            {
                g_pwelch_fft_input[xi_idx] = (float)x[j * slideN + xi_idx];
            }
            else
            {
                g_pwelch_fft_input[xi_idx] = 0.0f;
            }
        }

        arm_rfft_fast_f32(&g_pwelch_fft_instance,
                          g_pwelch_fft_input,
                          g_pwelch_fft_output,
                          0);

        // second point should be 0
        g_pwelch_fft_output[1] = 0.0f;

        /* 取模 */
        arm_cmplx_mag_f32(g_pwelch_fft_output,
                          g_pwelch_fft_magnitude,
                          xi_input_len / 2);

        // 完成 FFT 后，将幅值传递给后续功率谱计算。
        for (int X_idx = 0; X_idx < len_p - 1; X_idx++)
        {
            X[X_idx] = g_pwelch_fft_magnitude[X_idx];
        }
        X[len_p - 1] = 0.0;
#endif

                fft_cnt++;


        // 最后计算P值
        for (n = 0; n < len_p; n++)
        {
            // 由于是矩形窗，需要对P需要分情况讨论
            // 以下适用于dft
//            if (n == 0 || n == winN / 2) {
//                P[n] += (pow(cabs(X[n]), 2) / (K * winN)) / fs;
//            } else {
//                P[n] += (pow(cabs(X[n]), 2) / (K * winN)) / fs * 2;
//            }

            // 以下适用于rfft
            if (n == 0 || n == len_p-1)
            {
                P[n] += (pow(cabs(X[n]), 2) / (K * winN)) / fs;
            }
            else
            {
                P[n] += (pow(cabs(X[n]), 2) / (K * winN)) / fs * 2;
            }
						
						
        }
//				printf("P[%d]: %.15lf  \r\n", len_p-1,pow(X[n], 2));
    }

}
