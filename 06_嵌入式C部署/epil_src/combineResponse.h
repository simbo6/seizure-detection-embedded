//
// Created by CH on 2023/11/21.
//

#ifndef RECTRESPONDBACK_COMBINERESPONSE_H
#define RECTRESPONDBACK_COMBINERESPONSE_H

//typedef struct {
//    int start;
//    int end;
//    int peakLength;
//    int postLength;
//    int peakPeriod;
//} RangeInfo;

void combineResponse(int** range, int numRanges, int ids_final_emg, int range_combined[][5], int* numRanges_rc);

#endif //RECTRESPONDBACK_COMBINERESPONSE_H
