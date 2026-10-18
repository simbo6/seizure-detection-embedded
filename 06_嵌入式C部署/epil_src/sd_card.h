#ifndef SD_CARD_H
#define SD_CARD_H

//#include "ff.h"

// 在头文件中声明函数
int write_data_to_sd_card(const char* file_path, double data[], int rows);

int write_data_to_sd_card_2D(const char* file_path, double data[][3], int rows, int cols);

int write_data_to_sd_card_float(const char* file_path, float data[], int rows);

int write_data_to_sd_card_2D_float(const char* file_path, float** data, int rows, int cols);

int write_data_to_sd_card_int(const char* file_path, int data[], int rows);

int write_data_to_sd_card_2D_int(const char* file_path, int** data, int rows, int cols);




//double** read_data_from_txt_2D(const char* file_path, int start_row, int rows, int cols);

#endif // SD_CARD_H
