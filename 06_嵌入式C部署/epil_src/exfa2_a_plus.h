#include <math.h>
#include "pwelch.h"
#include <stdio.h>

/*
* 函数名称：bubbleSort。
* 函数功能：冒泡排序。
* 输入参数：x -- 输入数据指针，指针变量，double*。
*       len_x -- 输入数据长度，标量，int。
* 返回值：无。
*/

void BubbleSort(double *x, const int len_x) ;

/*
* 函数名称：exfa2。
* 函数功能：提取时域频域特征。
* 输入参数：x -- 输入数据指针，指针变量，double*。
*           winT -- 数据窗长，标量，int。
*           slideT -- 重叠率或重叠样本数，标量，int。
*           len_x -- 输入数据长度，标量，int。
*           feta -- 输出数组，指针变量，double*。
*           len_feta -- 输出特征长度，标量，int。
* 返回值：无。
*/
void exfa2_a_plus(
    const double *x,
    const int winT,
    const int slideT,
    const int len_x,
    const int fs,

    double *acc2,
    double *acc3,
    double *acc6,
    double *acc7,
    double *acc8,
    double *acc9,
    double *acc14,
    double *acc16,
    double *acc23,
    double *acc24);