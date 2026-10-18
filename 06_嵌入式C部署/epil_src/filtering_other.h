#include "filtfilt.h"

// void filtering(const double *acc41, 
//                  const int len_acc,  double* acc_filtfilt) {
// void filtering_other( const double *gyr41, const double *emg11,
//                  const int len_acc, const int len_emg, double* gyr_filtfilt, double* emg_filtfilt) ;
void filtering_other(  const double *emg11,
                 const int len_emg,  double* emg_filtfilt) ;
