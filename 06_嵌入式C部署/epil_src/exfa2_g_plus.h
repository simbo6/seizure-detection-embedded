#include <math.h>
#include "pwelch.h"
#include "exfa2_a_plus.h" // 好像没用到,不知道为什么要放在这里


void exfa1_g(const double *x, const int len_x, double* gyr1) ;
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
void exfa2_g_plus(
    const double *x,
    int winT,
    int slideT,
    int len_x,
    int fs,
    double *gyr10,
    double *gyr14,
    double *gyr17,
    double *gyr18,
    double *gyr23,
    double *gyr24) ;
