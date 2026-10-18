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
            double *emg1, double *emg2, double *emg3, double *emg4, double *emg5, double *emg7, double *emg8) ;