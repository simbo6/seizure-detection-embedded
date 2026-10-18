#include <stdio.h>
#include "main_EpilAlgo.h"
#include <string.h>
#include <stdlib.h>

#define MAX_FILES 1000
#define MAX_PATH_LENGTH 256




int findMin3(int a, int b, int c) {
    int min = a; // ???????????????ò??????????????a??????D?????
    if (b < min) {
        min = b; // ????????????ú??????????????????????D????????????????????????????D??μ
    }

    if (c < min) {
        min = c; // ???????????????????????????????????????D????????????????????????????D??μ
    }

    return min;
}

// ?????????????????????ú?????????????????????????·????????????????????????1???????????


// ?????????????????????ú????è???????????????

int main_test() 
{
//	        double acc[50][3];
//        double gyr[50][3];
//        double emg[200];
//        double acc_buffer[300][3];
//        double gyr_buffer[300][3];
//        double emg_buffer[1200];
//        double history_fits[15];
//        double history_smooth_fits[15];
//        int cnt = 0;
//        int cnt_f = 0;
//        int seizure = 0;
//        double fit = 0.0f;

//	main_EpilAlgo(acc, gyr, emg, acc_buffer, gyr_buffer, emg_buffer, history_fits, history_smooth_fits, &cnt,
//						 &cnt_f, &seizure, &fit);

						return 0;
}


//    int fileCount = 0;

//    if (dir == NULL) {
//        printf("无法打开文件夹：%s\n", folderPath);
//        return fileCount;
//    }

#if 0
int main_test() {
    // ??????è?????????????
    const char* folderPath = "D:\\EpilAlgoCTest\\cmake-build-debug\\"; // ???????????????·??????
    const char* keyword1 = "acc_data"; // ??????????????1
    const char* keyword2 = "gyr_data"; // ??????????????2
    const char* keyword3 = "emg_data"; // ??????????????3
    const char* keyword4 = "len_acc"; // ??????????????1
    const char* keyword5 = "len_gyr"; // ??????????????2
    const char* keyword6 = "len_emg"; // ??????????????3

    int fileCount = 0;

    char acc_data_filenames[MAX_FILES][MAX_PATH_LENGTH];
    char gyr_data_filenames[MAX_FILES][MAX_PATH_LENGTH];
    char emg_data_filenames[MAX_FILES][MAX_PATH_LENGTH];
    char len_acc_filenames[MAX_FILES][MAX_PATH_LENGTH];
    char len_gyr_filenames[MAX_FILES][MAX_PATH_LENGTH];
    char len_emg_filenames[MAX_FILES][MAX_PATH_LENGTH];
    fileCount = getAllFilenames(folderPath, keyword1, acc_data_filenames);
    fileCount = getAllFilenames(folderPath, keyword2, gyr_data_filenames);
    fileCount = getAllFilenames(folderPath, keyword3, emg_data_filenames);
    fileCount = getAllFilenames(folderPath, keyword4, len_acc_filenames);
    fileCount = getAllFilenames(folderPath, keyword5, len_gyr_filenames);
    fileCount = getAllFilenames(folderPath, keyword6, len_emg_filenames);

    // ????°??????è?????????????    for (int fileIdx = 0; fileIdx < fileCount; fileIdx++) {
        double len_acc[1];
        double len_gyr[1];
        double len_emg[1];
        readVectorFromFile_double(len_acc_filenames[fileIdx], len_acc, 1);
        readVectorFromFile_double(len_gyr_filenames[fileIdx], len_gyr, 1);
        readVectorFromFile_double(len_emg_filenames[fileIdx], len_emg, 1);

        int num_acc_data = (int)len_acc[0];
        int num_gyr_data = (int)len_gyr[0];
        int num_emg_data = (int)len_emg[0];
        int seconds_num1 = num_acc_data / 50;
        int seconds_num2 = num_gyr_data / 50;
        int seconds_num3 = num_emg_data / 200;

        int seconds_num = findMin3(seconds_num1, seconds_num2, seconds_num3);

        double (*acc_data)[3] = malloc((unsigned int)num_acc_data * sizeof(double[3]));
        double (*gyr_data)[3] = malloc((unsigned int)num_gyr_data * sizeof(double[3]));
        double *emg_data = malloc((unsigned int)num_emg_data * sizeof(double));

        readMatrixFromFile_double(acc_data_filenames[fileIdx], acc_data, num_acc_data, 3);
        readMatrixFromFile_double(gyr_data_filenames[fileIdx], gyr_data, num_gyr_data, 3);
        readVectorFromFile_double(emg_data_filenames[fileIdx], emg_data, num_emg_data);


////    // 示例输入数据
////    char str[10];
////
////    for (int fileIdx = 35; fileIdx <= 46; fileIdx++) {
////        sprintf(str, "%d", fileIdx);
////
////        double len_acc[1];
////        double len_gyr[1];
////        double len_emg[1];
////
////        char lfilename[50] = "len_acc";
////        char *numname = str;
////        char *txtname = ".txt";
////        strcat(lfilename, numname);
////        strcat(lfilename, txtname);
////        readVectorFromFile_double(lfilename, len_acc, 1);
////        char lfilename2[] = "len_gyr";
////        strcat(lfilename2, numname);
////        strcat(lfilename2, txtname);
////        readVectorFromFile_double(lfilename2, len_gyr, 1);
////        char lfilename3[] = "len_emg";
////        strcat(lfilename3, numname);
////        strcat(lfilename3, txtname);
////        readVectorFromFile_double(lfilename3, len_emg, 1);
////
////        int num_acc_data = (int)len_acc[0];
////        int num_gyr_data = (int)len_gyr[0];
////        int num_emg_data = (int)len_emg[0];
////        int seconds_num1 = num_acc_data / 50;
////        int seconds_num2 = num_gyr_data / 50;
////        int seconds_num3 = num_emg_data / 200;
////
////        int seconds_num = findMin3(seconds_num1, seconds_num2, seconds_num3);
////
////        double (*acc_data)[3] = malloc(num_acc_data * sizeof(double[3]));
////        double (*gyr_data)[3] = malloc(num_gyr_data * sizeof(double[3]));
////        double *emg_data = malloc(num_emg_data * sizeof(double));
////
////        char filename[50] = "acc_data";
////        strcat(filename, numname);
////        strcat(filename, txtname);
////        readMatrixFromFile_double(filename, acc_data, num_acc_data, 3);
////        char filename2[] = "gyr_data";
////        strcat(filename2, numname);
////        strcat(filename2, txtname);
////        readMatrixFromFile_double(filename2, gyr_data, num_gyr_data, 3);
////        char filename3[] = "emg_data";
////        strcat(filename3, numname);
////        strcat(filename3, txtname);
////        readVectorFromFile_double(filename3, emg_data, num_emg_data);
////
////        // 测试用fits
//////    double test_fits[seconds_num];
//////    char filename4[] = "fits";
//////    strcat(filename4,numname);
//////    strcat(filename4,txtname);
//////    readVectorFromFile_double(filename4, test_fits, seconds_num);
//////    for (int i = 0; i < seconds_num; i++) {
//////        if (test_fits[i] == -1) {
//////            test_fits[i] = -INFINITY;
//////        } else if (test_fits[i] == -2) {
//////            test_fits[i] = NAN;
//////        }
//////    }

        // ??????ê???????
        printf("Initialization\n");
        double acc[50][3];
        double gyr[50][3];
        double emg[200];
        double acc_buffer[300][3];
        double gyr_buffer[300][3];
        double emg_buffer[1200];
        double history_fits[15];
        double history_smooth_fits[15];
        int cnt = 0;
        int cnt_f = 0;
        int seizure = 0;
        double fit = 0.0f;

        // ?-???????￡??????????????ê???????????????????????￡?????1????′???????ò???????????????????
        printf("?-???????￡??????????????ê???????????????????????￡?????1????′???????ò???????????????????\n");
        int seizure_list[seconds_num];
        double fits[seconds_num]; // ???????????????ê·fit?μ??????????????????debug
        for (int i = 0; i < seconds_num; i++) {
            seizure_list[i] = -2; // ??????ê????????a-2
            fits[i] = -2;
        }

        printf("fileIdx / fileCount:  %d / %d\n", fileIdx+1, fileCount);

        // ??????????????ê?ê±??????
        clock_t start = clock();
        clock_t start1;

        for (int i = 0; i < seconds_num; i++) {
            for (int j = 0; j < 50; j++) { // ??????è?1?????????????????????                for (int k = 0; k < 3; k++) {
                    acc[j][k] = acc_data[i * 50 + j][k];
                    gyr[j][k] = gyr_data[i * 50 + j][k];
                }
            }
            for (int j = 0; j < 200; j++) {
                emg[j] = emg_data[i * 200 + j];
            }

            // ??????????????????????????????
            main_EpilAlgo(acc, gyr, emg, acc_buffer, gyr_buffer, emg_buffer, history_fits, history_smooth_fits, &cnt,
                          &cnt_f, &seizure, &fit);

            seizure_list[i] = seizure; // ??????????????????ê·?????????????μ
            fits[i] = fit;

            int mod = 200;
            int quotient = (i + 1) / mod;
            if (((i + 1) % mod == 0) && quotient % 2 == 0) { // ?????????????????????//                // ??????????????ê?ê±??????
//                start1 = clock();
                printf("%d\n", i + 1);
            } else if (((i + 1) % mod == 0) && quotient % 2 != 0) {
//                // ????????????????????ê±??????
//                clock_t end1 = clock();
//                // ?????????????′??????ê±????￡¨?????????????a??????????????
//                double elapsed_time1 = (double) (end1 - start1) / CLOCKS_PER_SEC;
                printf("%d\n", i + 1);
//                printf("elapsed_time1: %.2fs\n", elapsed_time1);
            }
        }

        // ????????????????????ê±??????
        clock_t end = clock();
        // ?????????????′??????ê±????￡¨?????????????a??????????????
        double elapsed_time = (double) (end - start) / CLOCKS_PER_SEC;
        printf("total time: %.2fs\n", elapsed_time);

        // ??????????????????
        char resfilename1[100] = "seizure_list_C_code_";
        char resfilename2[] = "fits_C_code_";

        removeChars(acc_data_filenames[fileIdx], 9);

        strcat(resfilename1, acc_data_filenames[fileIdx]);
//        strcat(resfilename1, txtname);
        writeVectorToFile_int(resfilename1, seizure_list, seconds_num);
        strcat(resfilename2, acc_data_filenames[fileIdx]);
//        strcat(resfilename2, txtname);
        writeVectorToFile_double(resfilename2, fits, seconds_num);

        printf("Array successfully written to file: %s\n", resfilename1);
        printf("Array successfully written to file: %s\n", resfilename2);

        free(acc_data);
        free(gyr_data);
        free(emg_data);

    }

    return 0;
}//
#endif
// Created by CH on 2023/11/21.
//
