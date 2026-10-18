#include "filtfilt.h"
#include "pwelch.h"
#include "exfa2_a_plus.h"
#include "exfa2_g_plus.h"
#include "exfemg_plus.h"

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
void calFeature2_plus(const double *acc_filtfilt, const double *gyr_filtfilt, const double *emg_filtfilt,
                 const int len_acc, const int len_emg, const int fs_acc, const int fs_emg,
                 double *acc2,double *acc3,double *acc6,double *acc7,double *acc8,double *acc9,double *acc14,double *acc16,double *acc23,double *acc24,
                     double *gyr10,double *gyr14,double *gyr17,double *gyr18,double *gyr23,double *gyr24,
                     double *emg1, double *emg2, double *emg3, double *emg4, double *emg5, double *emg7, double *emg8) {

    // 计算特征时作为窗口和每次滑动时跳过的时间长度（单位为秒）
    int winT = 4;    // winN = winT * fs;
    int slideT = 2;
									 
									 
    // 计算加速度特征
    exfa2_a_plus(acc_filtfilt, winT, slideT, len_acc, fs_acc,acc2,acc3,acc6,acc7,acc8,acc9,acc14,acc16,acc23,acc24);
									 
    // 计算角速度特征
    exfa2_g_plus(gyr_filtfilt, winT, slideT, len_acc, fs_acc, gyr10, gyr14, gyr17, gyr18, gyr23, gyr24);
		
    // 计算肌电特征
    exfemg_plus(emg_filtfilt, winT, slideT, len_emg, fs_emg, emg1, emg2, emg3, emg4, emg5, emg7, emg8);
		
}
