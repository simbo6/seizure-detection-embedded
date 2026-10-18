#include <math.h>
#include "pwelch.h"
#include <stdio.h>

/*
* 函数名称：exfemg3。
* 函数功能：提取一维向量的均值。
* 输入参数：emg -- 输入肌电数据指针，指针变量，double*。
*          winT -- 数据窗长，标量，int。
*        slideT -- 滑动窗长，标量，int。
*		len_emg -- 输入肌电数据长度，标量，int。
*            fs -- 采样率，标量，int。
*        fetemg -- 输入肌电特征，指针变量，double*。
*	  len_fetmg -- 特征数组长度，标量，int。
* 返回值：无。
*/
void exfemg_plus(const double *emg, const int winT, const int slideT, const int len_emg, const int fs,
            double *emg1, double *emg2, double *emg3, double *emg4, double *emg5, double *emg7, double *emg8) {

    int i, j;

    double sum1 = 0;//求解肌电积分值
    double sum2 = 0;//求解均方根
    double sum_mean = 0.0;
    double mean_seg = 0.0;
    for (i = 0; i < len_emg; i++)
    {
        sum_mean += emg[i];
    }
    mean_seg = sum_mean / len_emg;

    for (i = 0; i < len_emg; i++) {
        sum1 += fabs(emg[i]);
        sum2 += pow(emg[i], 2);
    }

    (*emg1) = sum1 / len_emg; //肌电积分值
    (*emg2) = sqrt(sum2);//均方根
    double sum_std = 0.0;
    for (i = 0; i < len_emg; i++)
    {
        sum_std += pow(emg[i] - mean_seg, 2.0);
    }
    (*emg3) = sqrt(sum_std / len_emg );

// 特征4: sum(segment.^2) 信号能量
    (*emg4) = sum2;

// 特征5: sum(abs(diff(segment))) 波形长度 WL
    double wl_sum = 0.0;
    for (i = 1; i < len_emg; i++)
    {
        wl_sum += fabs(emg[i] - emg[i - 1]);
    }
    (*emg5) = wl_sum;


    int count = 0;
    for (j = 0; j < len_emg; j++) {
        if (fabs(fabs(emg[j]) - (1) * 0.4 + 0.2) < 0.2) {//这几个值对应修改，未变其他值
            count++;//实现matlab内的find函数功能
        }
    }
    (*emg7) = count; //幅度直方图
    count = 0;
    for (j = 0; j < len_emg; j++) {
        if (fabs(fabs(emg[j]) - (2) * 0.4 + 0.2) < 0.2) {
            count++;//实现matlab内的find函数功能
        }
    }
    (*emg8) = count; //幅度直方图


}
