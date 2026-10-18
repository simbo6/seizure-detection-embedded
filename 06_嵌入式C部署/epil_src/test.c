//#include "sys.h"
//#include "delay.h"
#include "led.h"
#include "usart.h"
#include "lcd.h"
#include "ltdc.h"
#include "sdram.h"
#include "key.h"
#include "malloc.h"
#include "usmart.h"
#include "w25qxx.h"
#include "sdio_sdcard.h"
#include "ff.h"
#include "exfuns.h"
#include "ftl.h"
#include <string.h>
#include "rtc.h"
#include "main_EpilAlgo.h"
#include "sd_card.h"

//ALIENTEK 阿波罗STM32F429开发板 实验41
//FATFS 实验
//技术支持：www.openedv.com
//广州市星翼电子科技有限公司

//#define   acc_path   "acc_data.txt"
//#define   gyr_path   "gyr_data.txt"
//#define   emg_path   "emg_data.txt"

#define   acc_path   "acc_data_hmy0919.txt"
#define   gyr_path   "gyr_data_hmy0919.txt"
#define   emg_path   "emg_data_hmy0919.txt"

static char acc_buf[16];
static char emg_buf[16];
static char gyr_buf[16];

static  FIL  fp_acc_data;
static  FIL  fp_emg_data;
static  FIL  fp_gyr_data;

static float acc_array[100][3];
static float gyr_array[100][3];
static float emg_array[400];

static float acc_buffer[300][3];
static float gyr_buffer[300][3];
static float emg_buffer[1200];

double history_fits[16];
double history_smooth_fits[16];

int cnt = 0;
int cnt_f = 0;

int seizure = 0;

double fit = 0.0f;

#define secNum 120

//static  int seizure_list[9003];
double fits[secNum];

int main(void)
{
    // 时间统计
    u8 hour, min, sec, ampm;
    u16 ms;

    // 读取数据＋主循环
    u32 total, free;
    Stm32_Clock_Init(360, 25, 2, 8); //设置时钟,180Mhz
    delay_init(180);            //初始化延时函数
    uart_init(90, 115200);      //初始化串口波特率为115200
    usmart_dev.init(90);
    LED_Init();                 //初始化与LED连接的硬件接口
    SDRAM_Init();               //初始化SDRAM
    //LCD_Init();                   //初始化LCD
    KEY_Init();                 //初始化按键
    W25QXX_Init();              //初始化W25Q256

    RTC_Init();                 //初始化RTC
    RTC_Set_WakeUp(4, 0);       //配置WAKE UP中断,1秒钟中断一次

    my_mem_init(SRAMIN);        //初始化内部内存池
    my_mem_init(SRAMEX);        //初始化外部内存池
    my_mem_init(SRAMCCM);       //初始化CCM内存池

    while (SD_Init()) //检测不到SD卡
    {
        delay_ms(1000);
        LED0 = !LED0; //DS0闪烁
    }
    FTL_Init();
    exfuns_init();              //为fatfs相关变量申请内存
    f_mount(fs[0], "0:", 1);    //挂载SD卡
    while (exf_getfree("0", &total, &free)) //得到SD卡的总容量和剩余容量
    {
        delay_ms(200);
        LED0 = !LED0; //DS0闪烁
    }
    printf(">>>  SD Total Size:  %d MB  <<<\r\n>>>  SD  Free Size:  %dMB <<<", total, free);
    FRESULT  res;
    res = f_open(&fp_acc_data, acc_path, FA_OPEN_ALWAYS | FA_WRITE | FA_READ);
    if (res)
    {
        printf("fopen %s failed, [%d]\r\n", acc_path, (int)res);
    }
    else
    {
        printf("fopen %s success, [%d]\r\n", acc_path, (int)res);
    }

    res = f_open(&fp_gyr_data, gyr_path, FA_OPEN_ALWAYS | FA_WRITE | FA_READ);
    if (res)
    {
        printf("fopen %s failed, [%d]\r\n", gyr_path, (int)res);
    }
    else
    {
        printf("fopen %s success, [%d]\r\n", gyr_path, (int)res);
    }

    res = f_open(&fp_emg_data, emg_path, FA_OPEN_ALWAYS | FA_WRITE | FA_READ);
    if (res)
    {
        printf("fopen %s failed, [%d]\r\n", emg_path, (int)res);
    }
    else
    {
        printf("fopen %s success, [%d]\r\n", emg_path, (int)res);
    }

    unsigned int op_size = 0;
    int  t = 0;
    int  j = 0;
    int k = 0;
    uint8_t  dat = 0;
    int epilalgo_cnt = 1;

    //while(1)
    while (epilalgo_cnt <= secNum)
    {
        // 打印进度
        printf("------------------------------------------ %d --------------------------------------------\r\n", epilalgo_cnt);
        LED0 = !LED0;

        // 读取文件数据
        //------------------------------------------------acc---------------------------------------------
        j = 0;
        t = 0;
        k = 0;
        memset(acc_buf, 0, sizeof(acc_buf));
        for (;;)
        {
            f_read(&fp_acc_data, &dat, 1, &op_size);
            if (dat == ' ')
            {
                acc_buf[t] = 0x00;
                acc_array[j][k] = atof(acc_buf);
                t = 0;
                k++;
                if (k > 2)
                {
                    k = 0;
                    j++;
                    if (j >= 100)
                    {
                        break;
                    }
                }
            }
            else
            {
                acc_buf[t] = dat;
                t++;
            }
        }
        //------------------------------------------------gyr---------------------------------------------
        j = 0;
        t = 0;
        k = 0;
        memset(gyr_buf, 0, sizeof(gyr_buf));
        for (;;)
        {
            f_read(&fp_gyr_data, &dat, 1, &op_size);
            if (dat == ' ')
            {
                gyr_buf[t] = 0x00;
                gyr_array[j][k] = atof(gyr_buf);
                t = 0;
                k++;
                if (k > 2)
                {
                    k = 0;
                    j++;
                    if (j >= 100)
                    {
                        break;
                    }
                }
            }
            else
            {
                gyr_buf[t] = dat;
                t++;
            }
        }
        //------------------------------------------------emg-------------------------------------------------------------
        j = 0;
        t = 0;
        k = 0;
        memset(emg_buf, 0, sizeof(emg_buf));
        for (;;)
        {
            f_read(&fp_emg_data, &dat, 1, &op_size);
            if (dat == ' ')
            {
                emg_buf[t] = 0x00;
                emg_array[j] = atof(emg_buf);
                t = 0;
                j++;
                if (j >= 400)
                {
                    break;
                }
            }
            else
            {
                emg_buf[t] = dat;
                t++;
            }
        }

        // 癫痫算法入口
        //---------------------------------------MATH----------------------------------------------------
//      // 调用函数写入数据到SD卡
//        char filename[200];
//        int result;
//        sprintf(filename, "main_EpilAlgo_input_acc_array_sec%d.txt", epilalgo_cnt);  // 格式化数字到字符串中
//        result = write_data_to_sd_card_2D(filename, acc_array, 50, 3);
//        if (result == FR_OK) { printf("write %s success\r\n", filename); } else { printf("write %s failed\r\n", filename); }
//
//      sprintf(filename, "main_EpilAlgo_input_gyr_array_sec%d.txt", epilalgo_cnt);  // 格式化数字到字符串中
//        result = write_data_to_sd_card_2D(filename, gyr_array, 50, 3);
//        if (result == FR_OK) { printf("write %s success\r\n", filename); } else { printf("write %s failed\r\n", filename); }
//
//      sprintf(filename, "main_EpilAlgo_input_emg_array_sec%d.txt", epilalgo_cnt);  // 格式化数字到字符串中
//        result = write_data_to_sd_card(filename, emg_array, 200);
//        if (result == FR_OK) { printf("write %s success\r\n", filename); } else { printf("write %s failed\r\n", filename); }


//        RTC_Get_Time(&hour, &min, &sec, &ms, &ampm);  printf("\nmain_EpilAlgo start: %d : %d : %d : %d \r\n", hour, min, sec, ms);  // 获取开始时间

        main_EpilAlgo(acc_array, gyr_array, emg_array, acc_buffer, gyr_buffer, emg_buffer, history_fits, history_smooth_fits, &cnt, &cnt_f, &seizure, &fit);

//        RTC_Get_Time(&hour, &min, &sec, &ms, &ampm);  printf("\nmain_EpilAlgo end: %d : %d : %d : %d \r\n", hour, min, sec, ms);  // 获取结束时间


//      seizure_list[epilalgo_cnt-1] = seizure;
        fits[epilalgo_cnt - 1] = fit;


//      // 调用函数写入数据到SD卡
//      sprintf(filename, "main_EpilAlgo_output_seizure_sec%d.txt", epilalgo_cnt);  // 格式化数字到字符串中
//        result = write_data_to_sd_card_int(filename, &seizure, 1);
//        if (result == FR_OK) { printf("write %s success\r\n", filename); } else { printf("write %s failed\r\n", filename); }

//              sprintf(filename, "c_keil_rfft_fit_sec%d.txt", epilalgo_cnt);  // 格式化数字到字符串中
//        result = write_data_to_sd_card(filename, &fit, 1);
//        if (result == FR_OK) { printf("write %s success\r\n", filename); } else { printf("write %s failed\r\n", filename); }

        epilalgo_cnt++;
        printf("seizure: %d    fit: %.15f \r\n", seizure, fit);
    }

		char filename[200];
    int result;
    sprintf(filename, "c_keil_rfft_fits.txt");  // 格式化数字到字符串中
    result = write_data_to_sd_card(filename, fits, secNum);
    if (result == FR_OK)
    {
        printf("write %s success\r\n", filename);
    }
    else
    {
        printf("write %s failed\r\n", filename);
    }

		while(1){} // 一直待机
    delay_ms(30000);
    delay_ms(30000);
    delay_ms(30000);
    delay_ms(30000); // 待机2分钟，方便人工操作
    return 0;
}
