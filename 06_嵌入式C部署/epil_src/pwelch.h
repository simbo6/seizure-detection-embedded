//
// Created by CH on 2023/11/28.
//

#ifndef RECTRESPONDBACK_PWELCH_H
#define RECTRESPONDBACK_PWELCH_H

void pwelch(const double *x, const int len_x, const int slideN, const int winN, const double fs, double *P,

            const int len_p);

#endif //RECTRESPONDBACK_PWELCH_H
