#include "sd_card.h"
//#include "ff.h"

#include "string.h"
#include "stdlib.h"

// 其他头文件（根据需要添加）
//#include "sys.h"
//#include "delay.h"
//#include "usart.h"
#include "lcd.h"
#include "sdram.h"
#include "key.h"
#include "malloc.h"
#include "usmart.h"
#include "w25qxx.h"
#include "sdio_sdcard.h"
#include "exfuns.h"
#include "ftl.h"
#include "rtc.h"

int write_data_to_sd_card(const char* file_path, double data[], int rows) {
    FIL fp_data;
    FRESULT res;
    UINT bytes_written;

    res = f_open(&fp_data, file_path, FA_OPEN_ALWAYS | FA_WRITE);
    if (res != FR_OK) {
        return res; // 返回错误代码
    }

    for (int i = 0; i < rows; i++) {
		char buf[100];
		sprintf(buf, "%.15lf\n", data[i]);
        res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
        if (res != FR_OK) {
            f_close(&fp_data);
            return res; // 返回错误代码
        }
    }

    f_close(&fp_data);
    return FR_OK; // 返回成功代码
}

int write_data_to_sd_card_2D(const char* file_path, double data[][3], int rows, int cols) {
    FIL fp_data;
    FRESULT res;
    UINT bytes_written;

    res = f_open(&fp_data, file_path, FA_OPEN_ALWAYS | FA_WRITE);
    if (res != FR_OK) {
        return res; // 返回错误代码
    }

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            char buf[100];
            sprintf(buf, "%.15lf ", data[i][j]);  // 保存数据
            res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
            if (res != FR_OK) {
                f_close(&fp_data);
                return res; // 返回错误代码
            }
        }
		char buf[100];
		sprintf(buf, "\n");  // 换行
		res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
		if (res != FR_OK) {
			f_close(&fp_data);
			return res; // 返回错误代码
		}
    }

    f_close(&fp_data);
    return FR_OK; // 返回成功代码
}

int write_data_to_sd_card_float(const char* file_path, float data[], int rows) {
    FIL fp_data;
    FRESULT res;
    UINT bytes_written;

    res = f_open(&fp_data, file_path, FA_OPEN_ALWAYS | FA_WRITE);
    if (res != FR_OK) {
        return res; // 返回错误代码
    }

    for (int i = 0; i < rows; i++) {
		char buf[100];
		sprintf(buf, "%f\n", data[i]);
        res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
        if (res != FR_OK) {
            f_close(&fp_data);
            return res; // 返回错误代码
        }
    }

    f_close(&fp_data);
    return FR_OK; // 返回成功代码
}

int write_data_to_sd_card_2D_float(const char* file_path, float** data, int rows, int cols) {
    FIL fp_data;
    FRESULT res;
    UINT bytes_written;

    res = f_open(&fp_data, file_path, FA_OPEN_ALWAYS | FA_WRITE);
    if (res != FR_OK) {
        return res; // 返回错误代码
    }

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            char buf[100];
            sprintf(buf, "%f ", data[i][j]);  // 保存数据
            res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
            if (res != FR_OK) {
                f_close(&fp_data);
                return res; // 返回错误代码
            }
        }
		char buf[100];
		sprintf(buf, "\n");  // 换行
		res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
		if (res != FR_OK) {
			f_close(&fp_data);
			return res; // 返回错误代码
		}
    }

    f_close(&fp_data);
    return FR_OK; // 返回成功代码
}

int write_data_to_sd_card_int(const char* file_path, int data[], int rows) {
    FIL fp_data;
    FRESULT res;
    UINT bytes_written;

    res = f_open(&fp_data, file_path, FA_OPEN_ALWAYS | FA_WRITE);
    if (res != FR_OK) {
        return res; // 返回错误代码
    }

    for (int i = 0; i < rows; i++) {
		char buf[100];
		sprintf(buf, "%d\n", data[i]);
        res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
        if (res != FR_OK) {
            f_close(&fp_data);
            return res; // 返回错误代码
        }
    }

    f_close(&fp_data);
    return FR_OK; // 返回成功代码
}

int write_data_to_sd_card_2D_int(const char* file_path, int** data, int rows, int cols) {
    FIL fp_data;
    FRESULT res;
    UINT bytes_written;

    res = f_open(&fp_data, file_path, FA_OPEN_ALWAYS | FA_WRITE);
    if (res != FR_OK) {
        return res; // 返回错误代码
    }

    for (int i = 0; i < rows; i++) {
        for (int j = 0; j < cols; j++) {
            char buf[100];
            sprintf(buf, "%d ", data[i][j]);  // 保存数据
            res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
            if (res != FR_OK) {
                f_close(&fp_data);
                return res; // 返回错误代码
            }
        }
		char buf[100];
		sprintf(buf, "\n");  // 换行
		res = f_write(&fp_data, buf, strlen(buf), &bytes_written);
		if (res != FR_OK) {
			f_close(&fp_data);
			return res; // 返回错误代码
		}
    }

    f_close(&fp_data);
    return FR_OK; // 返回成功代码
}









//double** read_data_from_txt_2D(const char* file_path, int start_row, int rows, int cols) {
//    FILE* fp = fopen(file_path, "r");
//    if (fp == NULL) {
//        printf("Failed to open file: %s\n", file_path);
//        return NULL;
//    }

//    // 跳过指定的起始行
//    for (int i = 0; i < start_row; i++) {
//        char line[256];
//        if (fgets(line, sizeof(line), fp) == NULL) {
//            printf("Error: Failed to skip lines.\n");
//            fclose(fp);
//            return NULL;
//        }
//    }

//    double** data = (double**)malloc(rows * sizeof(double*));
//    if (data == NULL) {
//        printf("Memory allocation failed.\n");
//        fclose(fp);
//        return NULL;
//    }

//    for (int i = 0; i < rows; i++) {
//        data[i] = (double*)malloc(cols * sizeof(double));
//        if (data[i] == NULL) {
//            printf("Memory allocation failed.\n");
//            fclose(fp);
//            for (int j = 0; j < i; j++) {
//                free(data[j]);
//            }
//            free(data);
//            return NULL;
//        }

//        for (int j = 0; j < cols; j++) {
//            if (fscanf(fp, "%lf", &data[i][j]) != 1) {
//                printf("Error reading data from file.\n");
//                fclose(fp);
//                for (int k = 0; k <= i; k++) {
//                    free(data[k]);
//                }
//                free(data);
//                return NULL;
//            }
//        }
//    }

//    fclose(fp);
//    return data;
//}
