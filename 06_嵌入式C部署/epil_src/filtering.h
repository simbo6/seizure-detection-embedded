//
// Created by CH on 2023/11/28.
//

#ifndef RECTRESPONDBACK_FILTERING_H
#define RECTRESPONDBACK_FILTERING_H

void filtering(const double *acc41, const double *gyr41, const double *emg11,
               const int len_acc, const int len_emg, double* acc_filtfilt, double* gyr_filtfilt, double* emg_filtfilt);

#endif //RECTRESPONDBACK_FILTERING_H
