
/*
* 函数名称：combineResponse
* 函数功能：对区间处理--合并删除等。
* 输入参数： range[][5]: findRepond函数的输出结果，二维数组，int型。
*           numRanges：尖峰区间个数，变量，int。
*           ids_final_emg, 最终 ID，用于处理肌电信号，变量，int。
*           range_combined[][5]: 区间处理结果，二维数组，int型。
 *           numRanges_rc：range_combined中的尖峰区间个数-1，变量，int。
* 返回值：无
*/

//int N = 0; //N 用来记录range_combined 的最后一行  用于后续测试
void combineResponse(int** range, int numRanges, int ids_final_emg, int range_combined[][5], int* numRanges_rc) {
    // int N = 0; //N 用来记录range_combined 的最后一行  用于后续测试 
    // 标准尖峰：尖峰长度(10±2)+(0~5)，尖峰周期45
    range_combined[0][0] = range[0][0];
    range_combined[0][1] = range[0][1];
    range_combined[0][2] = range[0][2];

    // 根据当前区间和前区间的关系，对区间进行添加、合并、删除操作
    for (int i = 1; i < numRanges; i++) {
        // 情形1-前尖峰邻近：合并后的尖峰长度小于20，进行区间合并
         if (range[i][1] - range_combined[*numRanges_rc][0] + 1 < 20) {
            range_combined[*numRanges_rc][1] = range[i][1];
         }
        // 情形3-典型尖峰：周期大于等于40、尖峰大于等于8
         else if (range[i][4] >= 40 || range[i][2] >= 8) {
            int med = range[i][0] - range_combined[*numRanges_rc][1]; // 前一个非尖峰长度

            // 前尖峰邻近且短：尖峰长度小于10，相隔非尖峰长度小于20，进行区间删除
            if (range_combined[*numRanges_rc][2] < 10 && med < 20) {
                range_combined[*numRanges_rc][0] = range[i][0];
                range_combined[*numRanges_rc][1] = range[i][1];
            }
            // 前尖峰非邻近或不短：进行区间添加
            else {
                (*numRanges_rc)++;
                range_combined[*numRanges_rc][0] = range[i][0];
                range_combined[*numRanges_rc][1] = range[i][1];
            }
         }
         // 情形4-距离上一个尖峰太近：跳过当前区间
         else if (range[i][0] - range_combined[*numRanges_rc][0] < 40) {
             continue;
         }
         // 其他情形：添加当前区间
         else {
             (*numRanges_rc)++;
             range_combined[*numRanges_rc][0] = range[i][0];
             range_combined[*numRanges_rc][1] = range[i][1];
         }
         range_combined[*numRanges_rc][2] = range_combined[*numRanges_rc][1] - range_combined[*numRanges_rc][0] + 1;
    }
    for (int i = 0; i < (*numRanges_rc); i++) {
       
        // 计算非尖峰长度
         range_combined[i][3] = range_combined[i + 1][0] - range_combined[i][1] - 1;

        // 计算尖峰周期
         range_combined[i][4] = range_combined[i + 1][0] - range_combined[i][0];
    }
 // 计算最后一行的非尖峰长度和尖峰周期
    range_combined[*numRanges_rc][3] = ids_final_emg - range_combined[*numRanges_rc][1];
    range_combined[*numRanges_rc][4] = ids_final_emg - range_combined[*numRanges_rc][0] + 1;

    (*numRanges_rc)++; // 加1，使得numRanges_rc等于range_combined实际的行数。（从c语言中标识最后一行的索引，变为实际的行数）
}
