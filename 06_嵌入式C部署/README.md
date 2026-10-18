# 06 嵌入式 C 部署（STM32 在线版本）

本目录是算法从 MATLAB/Python 端落到嵌入式设备上的最终实现，源码来自原始 C 工程
（只读复制，未做任何修改）。
对应硬件为 ALIENTEK STM32F429 开发板，使用 SD 卡上的 txt 数据回放做离线在线验证，
并已在嵌入式环境完成实测。

## 1. 与上游链路的对应关系

```text
01_离线特征工程  ──┐
02_Python 训练   ──┼──> 04_模型参数（w, b, mean/std, FCM center）
03_MATLAB 在线   ──┘            │
                                ▼
                    手工硬编码进 C 源码（EpilAlgo1.c）
                                │
                                ▼
                      06_嵌入式C部署（本目录）
```

C 端**不读取 `.mat/.npy/.joblib`**，所有训练好的参数都以 `double` 数组直接写在
`epil_src/EpilAlgo1.c` 里。这是嵌入式端常见做法：裁剪掉文件 IO 与动态内存，
把常数表烧进 Flash。

## 2. 文件结构

| 文件 | 作用 | 与 MATLAB 端对应 |
|---|---|---|
| `main_EpilAlgo.c/h` | 每 1 秒被上层调用一次；维护 6 秒环形缓冲、16 点 fit 历史、NaN 插值、3 点平滑、阈值/连续窗判定 | `03_在线MATLAB测试/3_Buffers`、`9_PostProcess` |
| `EpilAlgo1.c/h` | 6 秒窗的核心算法：限幅 → 幅值 → 滤波 → 2 个运动特征 → zscore → FCM 运动门控 → 25 特征 → zscore → 线性 SVM → sigmoid | `5_Motion`、`6_EMG_Quality`、`7_Features`、`8_SVM` |
| `calFeature1.c/h` | 2 个运动前置特征（PS1） | `extract_imu_features_selected.m` 的运动子集 |
| `calFeature2_plus.c/h` | 25 个最终特征的装配入口 | `assemble_feature_vector.m` |
| `exfa2_a_plus.c/h` | ACC 通道特征 | `extract_imu_features_selected.m` |
| `exfa2_g_plus.c/h` | GYR 通道特征 | 同上 |
| `exfemg_plus.c/h` | EMG 通道特征 | `extract_emg_features_selected.m` |
| `exfMean.c/h` | EMG 基线漂移 SQI（6 段均值极差） | `check_emg_quality.m` |
| `filtering_acc.c/h`、`filtering_other.c/h`、`filtering.c/h`、`filtfilt.c/h` | 零相位滤波（ACC/GYR 一路、EMG 一路） | `filter_acc_gyr.m`、`filter_emg.m` |
| `pwelch.c/h` | Welch 功率谱（频域特征来源） | MATLAB `pwelch` 等价实现 |
| `Zscore.c`、`iterU.c`、`SVM.c`、`Sigmoid.c` | 标准化、FCM 隶属度、线性 SVM、sigmoid | `load_external_model.m`、`fcm_membership.m`、`svm_predict.m` |
| `combineResponse.c/h` | EMG 尖峰区间合并（历史脚本，主链路未调用，保留备查） | — |
| `sd_card.c/h` | FATFS 写文件封装 | — |
| `epil_porting.c/h` | `malloc/free/save` 的移植钩子，便于换 RTOS 或裸机 | — |
| `test.c` | STM32F429 板上 `main()`：初始化时钟/SD/FATFS，循环读 SD 上的 txt，每秒喂入并把 `seizure/fit` 写回 SD | 嵌入式实测入口 |
| `test_EpilAlgo.c` | PC 端批量回放的 main 框架（大部分被 `#if 0` 注释，仅保留接口） | — |

## 3. 调用时序

上层（传感器驱动或 SD 回放）每 1 秒调用一次 `main_EpilAlgo(...)`：

```c
// 1 秒新数据
float acc[100][3];   // 50 Hz × 2 s? 见下文说明
float gyr[100][3];
float emg[400];      // 200 Hz × 2 s

// 跨调用保留的缓冲区（由调用方分配并清零一次）
static float acc_buffer[300][3];   // 6 s @ 50 Hz
static float gyr_buffer[300][3];
static float emg_buffer[1200];      // 6 s @ 200 Hz
static double history_fits[16];
static double history_smooth_fits[16];
int cnt = 0, cnt_f = 0, seizure = 0;
double fit = 0;

main_EpilAlgo(acc, gyr, emg,
              acc_buffer, gyr_buffer, emg_buffer,
              history_fits, history_smooth_fits,
              &cnt, &cnt_f, &seizure, &fit);
// seizure: 0 无发作；1 发作；-1 信号质量不佳无法判定
```

启动条件：
- `cnt == 3` 时缓冲区攒够 6 秒（3 秒启动），开始调用 `EpilAlgo1`。
- `cnt_f == 16` 时历史队列满，开始做后处理与发作判定。
- 因此从冷启动到第一次能报 `seizure=1`，需要约 `3 + 16 = 19` 秒。

## 4. 关键算法参数（硬编码在 `EpilAlgo1.c` 与 `main_EpilAlgo.c`）

这些常数**必须**与 `04_模型参数/` 中的对应文件一致，否则 C 端与 MATLAB 端输出会对不上：

| 参数 | 位置 | 含义 | MATLAB 对应 |
|---|---|---|---|
| `±19.6` | `EpilAlgo1.c` 限幅 | ACC 三轴硬限幅（g） | `filter_acc_gyr.m` 的限幅 |
| `±8.5` | `EpilAlgo1.c` EMG 限幅 | EMG 限幅 | `filter_emg.m` |
| `sqi0 > 0.02` | `EpilAlgo1.c` | EMG 基线漂移阈值，超则 fit=NaN | `check_emg_quality.m` |
| `PS1_mean[2] / PS1_stdDev[2]` | `EpilAlgo1.c` | 2 个运动特征的 zscore 参数 | `normalization/norm_params_fold*.mat` |
| `mdl_FCM_2[2][2]`、`b=1.2` | `EpilAlgo1.c` | FCM 聚类中心与模糊指数 m | `fcm/fcm_params.mat`、`fcm/center.mat` |
| `PS2_mean[25] / PS2_stdDev[25]` | `EpilAlgo1.c` | 25 个最终特征的 zscore 参数 | 同上 |
| `w[25]`、`b_model=-1.78076…` | `EpilAlgo1.c` | 线性 SVM 权重与偏置 | `svm_6_filter/fold_*/w.npy`、`b.npy` |
| `epil_detect_thre = 0.7` | `main_EpilAlgo.c` | sigmoid 概率阈值 | `epilepsy_default_config.m` |
| `epil_detect_winSize = 5` | `main_EpilAlgo.c` | 连续 5 个点超阈才报警 | `check_continuous_alarm.m` |
| `HISTORY_LENGTH = 16` | `main_EpilAlgo.c` | fit 历史队列长度 | `smooth_latest.m` 的窗 |
| `interp_thre = 4` | `main_EpilAlgo.c` | 连续 NaN ≤4 可线性插值 | `interpolate_recent_nans.m` |
| 平滑点数 3 | `main_EpilAlgo.c` | 对最近 3 个非 NaN fit 取均值 | `smooth_latest.m` |

## 5. 与 MATLAB 在线版本的差异（重要）

| 维度 | MATLAB 在线（03） | C 嵌入式（本目录） |
|---|---|---|
| 推进周期 | 每 2 秒喂一次 | 每 1 秒喂一次 |
| 分析窗 | 最近 6 秒 | 最近 6 秒 |
| 历史队列 | 由配置决定 | 16 |
| 平滑窗 | 配置决定 | 3 |
| 启动时间 | 约 6 秒 | 约 3 + 16 = 19 秒 |
| 特征编号 | 1-based，与 MATLAB 一致 | 数组下标 0-based，但**特征排列顺序与 MATLAB 25 维向量一致**（见 `calFeature2_plus` 的实参顺序） |
| 模型加载 | 读 `04_模型参数` 的 `.mat/.npy` | 常数表硬编码 |

> 注意：C 端的"每秒一次"与 MATLAB 端的"每 2 秒一次"是两个独立调参版本，
> 不要把 `03_在线MATLAB测试` 的阈值原样搬到 C 端，也不要反过来。
> 引用本版本时应明确说明当前交付的是"1 秒推进、3 点平滑、5 点连续报警"的嵌入式版本。

## 6. 移植到其他 MCU / RTOS 的要点

1. **替换移植层**：`epil_porting.c` 里的 `epil_malloc / epil_free / epil_port_save`
   是唯一对外的内存/日志钩子。主链路其实用的是静态数组，移植时可以直接把这三个函数
   接到 RTOS 的 `pvPortMalloc / vPortFree` 或直接做空实现。
2. **保留静态内存**：`acc_buffer[300][3]`、`history_fits[16]` 等都是调用方分配的
   静态数组，不需要堆。RAM 占用约几 KB，适合 Cortex-M4/M7。
3. **数学库**：依赖 `<math.h>` 的 `sqrt/pow/exp/isnan/INFINITY`。
   注意 `pow(x, 2)` 在 `iterU.c` 里被反复调用，对定点 MCU 建议改成 `x*x`。
4. **特征顺序**：`calFeature2_plus(...)` 的 25 个输出参数已经按 `PS2_mean/stdDev/w`
   的顺序填进 `testset2[1..24]`，再把 `testset1[0]/testset1[1]` 塞进
   `testset2[0]/testset2[7]`。改特征集时必须同步改这三处，否则 zscore/SVM 会错位。
5. **数据来源**：`test.c` 是从 SD 卡 txt 读回放数据；上真实传感器时，把
   `acc_array[100][3] / gyr_array[100][3] / emg_array[400]` 换成 DMA 接收缓冲区即可，
   `main_EpilAlgo` 接口不变。
6. **输出**：`seizure` 返回给上层驱动（LED / 蜂鸣器 / 蓝牙），`fit` 可写日志或上传。

## 7. 未包含的内容

- STM32 HAL 库、启动文件、`led.h/usart.h/ltdc.h/sdio_sdcard.h/ff.h` 等板级支持包
  未复制（这些是 ALIENTEK 例程自带，不属于算法代码）。
- 板上实测用的 `acc_data_hmy0919.txt` 等脱敏回放数据未复制（含患者信息）。
- `combineResponse.c` 是 EMG 尖峰历史脚本，主链路未调用，仅作遗留参考。
