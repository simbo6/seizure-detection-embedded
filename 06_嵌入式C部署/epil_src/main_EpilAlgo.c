#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <math.h>

#include "EpilAlgo1.h"
#include "epil_porting.h"


//// 性能分析使用
//#include <time.h>
//#include <windows.h>
//double getElapsedTime(LARGE_INTEGER start, LARGE_INTEGER end, LARGE_INTEGER frequency) {
//    return (double)(end.QuadPart - start.QuadPart) / frequency.QuadPart;
//}
//// 性能分析使用

#define HISTORY_LENGTH 16
#define EMG_DATA_SIZE 400
#define ACC_DATA_SIZE 100

/*
* 函数名称：main_EpilAlgo�?
* 函数功能：癫痫算法函数主框架，包含后处理逻辑�?
 * 注意：因C语言环境与MATLAB有较大不同，所以该函数的实现方式会与MATLAB在线版本有较大的不同�?
* 输入参数：acc -- 这一秒的加速度数据，静态二维数组，大小�?0×3，double**�?
*           gyr -- 这一秒的角速度数据，静态二维数组，大小�?0×3，double**�?
*           emg -- 这一秒的肌电数据，静态一维数组，大小�?00×1，double**�?
 *          acc_buffer -- 历史加速度数据缓存区，动态二维数组，大小�?50×3，double**�?
 *          gyr_buffer -- 历史角速度数据缓存区，动态二维数组，大小�?50×3，double**�?
 *          emg_buffer -- 历史肌电数据缓存区，动态二维数组，大小�?000×1，double**�?
 *          history_fits -- 历史svm输出的原始fit值，动态一维数组，大小�?×14，double**�?
 *          history_smooth_fits -- 历史平滑后的fit值，动态一维数组，大小�?×14，double**�?
 *          cnt -- 计数算法调用次数，用于判断是否满足启动条件，标量，int*�?
* 返回值：seizure -- 是否发作的返回值，1为发作，0为不发作�?1为信号质量不佳，标量，int�?
*/

// 定义用于搜索history_fits最�?位中连续NaN子序列的结构�?
typedef struct {
    int start;
    int end;
    int length;
} NaNSubsequence;

// 函数声明
double nonNaN_smooth(double history[], int startIdx, int endIdx) {
    // 实现平滑函数的代�?
    double smoothed_value;
    double sum = 0;
    int cnt = 0;
    for (int i = startIdx; i <= endIdx; i++) {
        if (!isnan(history[i])) {
            sum += history[i];
            cnt++;
        }
    }
    smoothed_value = sum / (double)cnt;
    return smoothed_value;
}
#if 0
// 实现查找所有NaN子序列的函数代码
NaNSubsequence* FindAllNaNSubsequences(double history[], int interp_thre, int* cnt_subsequences) {
    NaNSubsequence* subsequences = NULL;
    int sequence_start = -1;
    int sequence_length = 0;
    int i;

    // 遍历历史数据
    for (i = 0; i < HISTORY_LENGTH; i++) {
        if (isnan(history[i])) {
            // 如果当前元素是NaN
            if (sequence_start == -1) {
                // 如果还没有开始记录子序列
                sequence_start = i;
                sequence_length = 1;
            } else {
                // 如果已经开始记录子序列
                sequence_length++;
            }
        } else {
            // 当前元素不是NaN
            if (sequence_start != -1 && sequence_length <= interp_thre && sequence_start != 0 && sequence_start + sequence_length - 1 != HISTORY_LENGTH-1) {
                // 检查子序列是否满足条件，并将其添加到结果中
                (*cnt_subsequences)++;
                NaNSubsequence* new_subsequences = (NaNSubsequence*)realloc(subsequences, (*cnt_subsequences) * sizeof(NaNSubsequence));
                if (new_subsequences == NULL) {
                    // 处理内存分配失败的情�?
                    // 可以选择释放原始缓冲区的内存
                    epil_free(subsequences);
                    subsequences = NULL;
                    *cnt_subsequences = 0;
                } else {
                    subsequences = new_subsequences;

                    subsequences[*cnt_subsequences - 1].start = sequence_start;
                    subsequences[*cnt_subsequences - 1].end = sequence_start + sequence_length - 1;
                    subsequences[*cnt_subsequences - 1].length = sequence_length;
                }
            }
            // 重置子序列记�?
            sequence_start = -1;
            sequence_length = 0;
        }
    }

    return subsequences;
}
#endif
// 实现查找所有NaN子序列的函数代码
NaNSubsequence* FindAllNaNSubsequences(double history[], int interp_thre, int* cnt_subsequences) {
	static NaNSubsequence subsequences[HISTORY_LENGTH];
    int sequence_start = -1;
    int sequence_length = 0;
    int i;

	memset(subsequences, 0, sizeof(NaNSubsequence));

    // 遍历历史数据
    for (i = 0; i < HISTORY_LENGTH; i++) {
        if (isnan(history[i])) {
            // 如果当前元素是NaN
            if (sequence_start == -1) {
                // 如果还没有开始记录子序列
                sequence_start = i;
                sequence_length = 1;
            } else {
                // 如果已经开始记录子序列
                sequence_length++;
            }
        } else {
            // 当前元素不是NaN
            if (sequence_start != -1 && sequence_length <= interp_thre && sequence_start != 0 && sequence_start + sequence_length - 1 != HISTORY_LENGTH-1) {
                // 检查子序列是否满足条件，并将其添加到结果中
                (*cnt_subsequences)++;
				#if 0
                NaNSubsequence* new_subsequences = (NaNSubsequence*)realloc(subsequences, (*cnt_subsequences) * sizeof(NaNSubsequence));
                if (new_subsequences == NULL) {
                    // 处理内存分配失败的情�?
                    // 可以选择释放原始缓冲区的内存
                    epil_free(subsequences);
                    subsequences = NULL;
                    *cnt_subsequences = 0;
                } else {
                    subsequences = new_subsequences;
				#endif

                    subsequences[*cnt_subsequences - 1].start = sequence_start;
                    subsequences[*cnt_subsequences - 1].end = sequence_start + sequence_length - 1;
                    subsequences[*cnt_subsequences - 1].length = sequence_length;
                //}
            }
            // 重置子序列记�?
            sequence_start = -1;
            sequence_length = 0;
        }
    }

    return (NaNSubsequence* )subsequences;
}




int EpilepsyDetection(const double history_smooth_fits[], double epil_detect_thre, int epil_detect_winSize) {
    int seizure = 0;  // 默认0：无发作

    // 癫痫检�?
    int length = HISTORY_LENGTH;
    int label[HISTORY_LENGTH];

    for (int i = 0; i < length; i++) { // 初始化标签序�?
        label[i] = -1;
        if (history_smooth_fits[i] > epil_detect_thre) { // 如果fit超过阈值，则将那个标签置为1
            label[i] = 1;
        }
    }

    int last_labels = 1;
    for (int i = length - epil_detect_winSize; i < length; i++) { // 遍历最�?个标�?
        if (label[i] != 1) {
            last_labels = 0;
            break;
        }
    }

    if (last_labels == 1) { // 如果最�?个标签全�?
        seizure = 1;  // 视为发作
    }

    return seizure;
}

// int check_tail_nan(const double history_fits[], int array_size, int e_p_w) {
//     // 参数验证
//     if (e_p_w <= 0 || e_p_w > array_size) {
//         return 0;  // 如果e_p_w无效，返�?（视为没有NaN�?
//     }
    
//     // 检查最后e_p_w个元�?
//     for (int i = array_size - e_p_w; i < array_size; i++) {
//         if (isnan(history_fits[i])) {
//             return 1;  // 发现NaN，立即返�?
//         }
//     }
    
//     return 0;  // 没有发现NaN
// }

void main_EpilAlgo(float acc[][3], float gyr[][3], float emg[], float acc_buffer[][3], float gyr_buffer[][3], float emg_buffer[],
                   double history_fits[], double history_smooth_fits[], int* cnt, int* cnt_f, int* seizure, double* fit) {
    // 参数
    double epil_detect_thre = 0.7f; // 癫痫检测阈�?  // 修改�?.6-0.8~0.75
    int history_fits_length = 16; // 设定的保留的历史队列长度
    int interp_thre = 4; // 插值的阈�?
    int epil_detect_winSize = 5; // 癫痫检测的窗长

    // 默认为无发作
    *seizure = 0;

    // 输出默认fit，用于debug
    *fit = -INFINITY;
										 

    // 数据预处�?
   // emgRemoveOnOff(&emg[0], EMG_DATA_SIZE/2, &emg[0]); // �?秒调用一次版：处�?秒中的第1�?// 修改，用不到，注释掉
   // emgRemoveOnOff(&emg[200], EMG_DATA_SIZE/2, &emg[200]); // �?秒调用一次版：处�?秒中的第2�?
										 		

    // 检查缓存区是否已满
    if ((*cnt) == 3) {
        // 清空最早的第一次调用时传入的缓存数�?
        for (int i = 0; i < 200; i++) {
            for (int j = 0; j < 3; j++) {
                acc_buffer[i][j] = acc_buffer[i + 100][j];
                gyr_buffer[i][j] = gyr_buffer[i + 100][j];
            }
        }

        for (int i = 0; i < 800; i++) {
            emg_buffer[i] = emg_buffer[i + 400];
        }

        // 重置cnt
        (*cnt)--; // 缓存区目前少了一秒的数据，即保存�?秒的数据�?
    }

    // 将预处理数据加入缓存�?
    int buffer_index = *cnt * ACC_DATA_SIZE;
    for (int i = 0; i < 100; i++) {
        for (int j = 0; j < 3; j++) {
            acc_buffer[buffer_index + i][j] = acc[i][j];
            gyr_buffer[buffer_index + i][j] = gyr[i][j];
        }
    }

    int buffer_index2 = *cnt * EMG_DATA_SIZE;
    for (int i = 0; i < 400; i++) {
        emg_buffer[buffer_index2 + i] = emg[i];
    }

    // 启动时期的调用次数计数，因C语言中没法判断缓存区中已存入多少有效数据。代表缓存区中保存有多少秒的数据�?
    (*cnt)++;


    if (*cnt == 3) { // 缓存区中�?秒历史预处理数据，满足EpilAlgo1启动条件�?


        // EpilAlgo1：预�?
        *fit = EpilAlgo1(acc_buffer, gyr_buffer, emg_buffer); // 非运动：fit=0；信号质量不佳：fit=NaN�?
			
		epil_port_save(*fit);
	
        // 检查历史队列是否已�?
        if (*cnt_f == 16) {
            // 清空最早的第一次调用缓存（在C语言中，比较方便的做法是把后面的数据往前移�?
            for (int i = 0; i < 15; i++) {
                history_fits[i] = history_fits[i + 1];
                history_smooth_fits[i] = history_smooth_fits[i + 1];
            }
            (*cnt_f)--;
        }

        // 当前fit加入历史队列
        history_fits[*cnt_f] = *fit; // 加入到最后一个位�?
        (*cnt_f)++;

        // EpilAlgo2：插值与平滑
        if (*cnt_f == history_fits_length) { // 已有16个历史fit值，满足EpilAlgo2（后处理）完整启动条件�?
            if (isnan(history_fits[11]) ||isnan(history_fits[12]) ||isnan(history_fits[13]) || isnan(history_fits[14]) || isnan(history_fits[15])) { // （历史原始队列）最�?个点存在NaN

                int cnt_subsequences = 0; // 初始�?
                NaNSubsequence* subsequences = FindAllNaNSubsequences(history_fits, interp_thre, &cnt_subsequences); // 遍历�?

                if (cnt_subsequences != 0) { // 传回的子序列非空：（历史原始队列）：存在可插值的nan
                    // 对能够插值的点进行插�?
                    for (int i = 0; i < cnt_subsequences; i++) {

                        double prev = history_fits[subsequences[i].start - 1]; // 取出子序列之前的一个非NaN�?
                        double next = history_fits[subsequences[i].end + 1]; // 取出子序列之后的一个非NaN�?
                        double offset = (next - prev) / (double)(subsequences[i].length + 1); // 计算每一阶的插值数�?

                        // 插值结果放入history_fits中，顺便平滑�?
                        for (int j = subsequences[i].start; j <= subsequences[i].end; j++) { // 遍历插值点
                            history_fits[j] = history_fits[j-1] + offset; // 一阶一阶加上去…�?

                            // 对平滑队列中的位置进行平�?
                            int startIdx;
                            int endIdx = j;
                            // if (j <= 5) { // 前面的值不超过5�?
                            if (j <= 2) { // 前面的值不超过5�? // �?�?
                                startIdx = 0;
                            } else {
                                // startIdx = j-5;
                                startIdx = j-2; // �?�?
                            }
                            history_smooth_fits[j] = nonNaN_smooth(history_fits, startIdx, endIdx); // 平滑该位置的值，并将结果放入平滑队列�?
                        }
                    }
                    // 如果新fit不为NaN，则对历史原始队列的最后一个点（也就是新fit）进行平�?
                    if (!isnan(*fit)) {
                        // history_smooth_fits[HISTORY_LENGTH-1] = nonNaN_smooth(history_fits, HISTORY_LENGTH-6, HISTORY_LENGTH-1); // 平滑该位置的值，并将结果放入平滑队列�?
                        history_smooth_fits[HISTORY_LENGTH-1] = nonNaN_smooth(history_fits, HISTORY_LENGTH-4, HISTORY_LENGTH-1); // 平滑该位置的值，并将结果放入平滑队列�? 平滑点数�?变为3
                    } else {
                        history_smooth_fits[HISTORY_LENGTH-1] = *fit; // 当前fit加入历史平滑队列（位置是最后一位）
                    }

                    if (isnan(history_fits[11]) ||isnan(history_fits[12]) ||isnan(history_fits[13]) || isnan(history_fits[14]) || isnan(history_fits[15])) { // （历史平滑队列）（最�?个点）仍然存在NAN
                        *seizure = -1; // seizure返回-1，表示因信号质量不佳无法检�?
                    } else { // 癫痫检�?
                        *seizure = EpilepsyDetection(history_smooth_fits, epil_detect_thre, epil_detect_winSize);
                    }
                } else { // （历史原始队列）能否插值：不存在可插值的nan
                    // 对能够平滑的点进行平滑（这种情况下，只有新fit有可以被平滑的可能性）

                    // 如果新fit不为NaN，则对历史原始队列的最后一个点（也就是新fit）进行平�?
                    if (!isnan(*fit)) {
                        // history_smooth_fits[HISTORY_LENGTH-1] = nonNaN_smooth(history_fits, HISTORY_LENGTH-6, HISTORY_LENGTH-1); // 平滑该位置的值，并将结果放入平滑队列�?
                        history_smooth_fits[HISTORY_LENGTH-1] = nonNaN_smooth(history_fits, HISTORY_LENGTH-4, HISTORY_LENGTH-1); // 平滑该位置的值，并将结果放入平滑队列�? 平滑点数�?变为3
                    } else {
                        history_smooth_fits[HISTORY_LENGTH-1] = *fit; // 当前fit加入历史平滑队列（位置是最后一位）
                    }

                    *seizure = -1; // seizure返回-1，表示因信号质量不佳无法检�?
                }


                //////////////////////////////////////////////////////////////
                //epil_free(subsequences);  // 这里需要释�?FindAllNaNSubsequences 函数内用 realloc 申请的内存！！！！！！！！！！！


            } else { // （历史原始队列）最�?个点不存在NaN
                // 对能够平滑的点进行平滑（这种情况下，也就是平滑新fit点）
                // history_smooth_fits[HISTORY_LENGTH-1] = nonNaN_smooth(history_fits, HISTORY_LENGTH-6, HISTORY_LENGTH-1); // 平滑该位置的值，并将结果放入平滑队列�?
                history_smooth_fits[HISTORY_LENGTH-1] = nonNaN_smooth(history_fits, HISTORY_LENGTH-4, HISTORY_LENGTH-1); // 平滑该位置的值，并将结果放入平滑队列�? 平滑点数�?变为3
                // 癫痫检�?
                *seizure = EpilepsyDetection(history_smooth_fits, epil_detect_thre, epil_detect_winSize);
            }
        } else { // 不满足EpilAlgo2（后处理）完整启动条件�?
            // 对平滑队列中的位置进行平�?
            int startIdx;
            int endIdx = *cnt_f-1;
            // if (*cnt_f <= 6) { // 如果个数�?，全部用于进行平�?
            if (*cnt_f <= 4) { // 如果个数�?，全部用于进行平�?  �?�?
                startIdx = 0;
            } else {
                // startIdx = *cnt_f- 1 - 5;
                startIdx = *cnt_f- 1 - 3;  //�?�?
            }
            history_smooth_fits[*cnt_f-1] = nonNaN_smooth(history_fits, startIdx, endIdx); // 平滑该位置的值，并将结果放入平滑队列�?
        }
    }
}
