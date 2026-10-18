#include <math.h>

void BubbleSort(double *x, const int len_x) ;


void exfa1(const double *x, const int len_x, double* acc1, double* acc10) {

    // 一些转换后的信号
    double dx[len_x];

    int i;

    dx[0] = 0;
    for (i = 1; i < len_x; i++) {
        dx[i] = x[i] - x[i - 1];	// x的差
    }//这里用不到计算差分，浪费

    // double x_sort[len_x];			// 绝对值的排序
    // for (i = 0; i < len_x; i++) {
    //     x_sort[i] = fabs(x[i]);
    // }

    // for (i = 0; i < len_x; i++) {
    //     (*acc1) += x_sort[i];		// 绝对值的均值
    // }
    for(int i=0; i<len_x; i++){
    *acc1 += fabs(x[i]);
}
    (*acc1) /= len_x; // acc_1,绝对均值

    // BubbleSort(x_sort, len_x); //这里之前没加冒泡排序相关内容，移植过来

    // (*acc5) = x_sort[149]; //acc_5,50%分位点

    for (i = 1; i < len_x; i++) {
        if ((x[i] * x[i - 1] <= 0) && (fabs(dx[i]) > 5)) {
            (*acc10)++;
        }
    } //过零点  // acc_10,暂时用不到，移至他处

}

// void exfa1_g(const double *x, const int len_x, double* gyr1) {
//     int i;

//     double x_sort[len_x];			// 绝对值的排序
//     for (i = 0; i < len_x; i++) {
//         x_sort[i] = fabs(x[i]);
//     }

//     for (i = 0; i < len_x; i++) {
//         (*gyr1) += x_sort[i];		// 绝对值的均值
//     }
//     (*gyr1) /= len_x;

// }


/*
* 函数名称：calFeature4。
* 函数功能：提取acc，gyr，emg的多个特征。
			请确保传入的信号已经经过前期处理，如加速度合并为一维数组，检查不存在NAN等。
* 输入参数：acc -- 加速度，指针变量，double*。
*           gyr -- 加速度，指针变量，double*。
*           emg -- 加速度，指针变量，double*。
*       len_acc -- acc、gyr的元素数目，标量，int。
*       len_emg -- emg的元素数目，标量，int。
*        fs_acc -- acc、gyr的采样率，标量，int。
*        fs_emg -- emg的采样率，标量，int。
*      features -- 特征结果指针，指针变量，double*。
				   我之前试图把它的长度传到函数里面，但发现不需要，
				   因为这个变量是由两个特征提取函数的输出决定的，
				   所以这里需要提前规划好输出的特征数量，否则可能因为索引出现报错。
* 返回值：无。
*/
// void calFeature1(const double *acc_filtfilt, const double *gyr_filtfilt, int len_acc, double* acc1, double* acc10, double* gyr1) {
void calFeature1(const double *acc_filtfilt,  int len_acc, double* acc1, double* acc10) { // 修改
    // 计算加速度特征
    exfa1(acc_filtfilt, len_acc, acc1, acc10);

    // 计算角速度特征
 //   exfa1_g(gyr_filtfilt, len_acc, gyr1); // 修改，这里用不到，会移到其他地方

}

//
// Created by CH on 2023/11/28.
//
