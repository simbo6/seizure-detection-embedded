//
// Created by CH on 2023/11/17.
//

#ifndef RECTRESPONDBACK_MAIN_EPILALGO_H
#define RECTRESPONDBACK_MAIN_EPILALGO_H

void main_EpilAlgo(float acc[][3], float gyr[][3], float emg[], float acc_buffer[][3], float gyr_buffer[][3], float emg_buffer[],
                   double history_fits[], double history_smooth_fits[], int* cnt, int* cnt_f, int* seizure, double* fit);

#endif //RECTRESPONDBACK_MAIN_EPILALGO_H
