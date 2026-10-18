# 在线发作检测模型：离线训练 → MATLAB 在线测试 → C 嵌入式部署

本项目是一套完整的在线癫痫发作检测算法工程，覆盖从离线信号处理、样本构建、特征选择、
Python SVM 训练，到 MATLAB 在线回放，再到 STM32 嵌入式 C 部署的完整链路。

## 1. 项目主线

```text
原始 MAT 信号
  -> MATLAB 预处理/滤波/窗口划分/特征提取          [01]
  -> 五折切分、标准化、FCM 聚类与特征选择
  -> Python 训练 Linear SVM，导出 w.npy/b.npy       [02]
  -> 模型参数成套归档                                [04]
  -> MATLAB 每 2 秒更新一次缓存并提取 6 秒窗口特征    [03]
  -> SVM 概率/分数 + 平滑、连续报警与事件合并
  -> points.csv / events.xlsx / result.mat
  -> 参数硬编码进 C，STM32F429 每秒喂数、6 秒窗判定   [06]
  -> seizure 0/1/-1 输出到 LED / 串口 / SD 日志
```

## 2. 目录导航

- `01_离线数据处理与特征工程`：预处理、信号质量、窗口特征、五折划分、FCM 和特征选择 MATLAB 代码。
- `02_Python训练与后处理`：SVM 训练、类别不平衡处理、参数搜索和窗口预测到发作事件的统计脚本。
- `03_在线MATLAB测试`：模块化在线回放版本。入口在 `1_Main`，算法组件按模块分目录。
- `04_模型参数`：最小运行参数集，包括 SVM 权重、归一化参数、FCM 参数和特征选择 CSV。
- `05_文档`：运行说明、数据接口、参数说明、版本记录和检查清单。
- `06_嵌入式C部署`：STM32 端 C 源码（只读复制自原始 C 工程），含调用时序、参数对应表和移植要点，见该目录下 `README.md`。

患者原始数据、训练中间矩阵和批量结果未包含在本仓库中，详见 `05_文档/来源与取舍说明.md`。

## 3. 最短运行路径

### MATLAB 在线回放

1. 打开 `03_在线MATLAB测试/1_Main/online_project_config.m`。
2. 将 `data_root`、`fold_info_file` 和 `true_events_file` 改为本机路径。
3. 在 MATLAB 中将当前目录切到 `03_在线MATLAB测试/1_Main`，执行：

```matlab
root = fileparts(pwd);
addpath(fullfile(root, '0_Utils'));
setup_online_detector_paths(root);
out = run_online_pipeline('你的数据目录', 1);
```

单文件和批处理的完整接口见 `03_在线MATLAB测试/1_Main/README_运行接口.md`。

### Python 训练

训练脚本位于 `02_Python训练与后处理/svm`。推荐先阅读 `cross_train.py` 的输入、五折划分和导出逻辑，再根据数据位置修改脚本配置。MAT v7.3 文件使用 `h5py` 读取；训练输出中的 `w.npy`、`b.npy` 是 MATLAB 在线 SVM 预测所需的核心文件。

### 嵌入式 C（STM32）

C 端不读外部模型文件，参数已硬编码在 `06_嵌入式C部署/epil_src/EpilAlgo1.c`。
移植/复测要点见 `06_嵌入式C部署/README.md`；板上入口是 `test.c`（ALIENTEK STM32F429 例程环境），
算法主入口是 `main_EpilAlgo(...)`，由上层每 1 秒喂入 1 秒新数据。

## 4. 如何把本项目装入 MATLAB

完整步骤见 `05_文档/MATLAB_导入与运行.md`，最短路径：

```matlab
% 1. 把项目根目录加入 MATLAB 搜索路径（一次性，写进 startup.m 更省心）
projRoot = '你的项目根目录';   % 例如 D:\seizure-detection-embedded
addpath(genpath(fullfile(projRoot, '03_在线MATLAB测试')));

% 2. 切到在线主目录并初始化路径
cd(fullfile(projRoot, '03_在线MATLAB测试', '1_Main'));
root = fileparts(pwd);
addpath(fullfile(root, '0_Utils'));
setup_online_detector_paths(root);

% 3. 改 online_project_config.m 里的 data_root / fold_info_file / true_events_file，然后
out = run_online_pipeline('你的数据目录', 1);
```

模型参数默认从 `04_模型参数` 读取，无需手工拷贝；切换 fold 或特征数量时只改
`online_project_config.m` 中的对应字段即可。

## 5. 重要约定

- MATLAB 特征编号是 1-based；Python 数组索引通常是 0-based，转换时必须减 1。
- MATLAB 在线端是 **2 秒推进、6 秒窗**；C 嵌入式端是 **1 秒推进、6 秒窗**，两端阈值/平滑窗独立调过，不要直接互搬参数。
- 训练、MATLAB 在线、C 部署三处必须使用同一套采样率、特征顺序、归一化参数和特征编号。
- `main_preprocess_feature.m` 是历史批处理脚本，其中包含删除输入 MAT 文件的语句，不要把它当作无副作用演示入口。
- 本项目不包含患者原始数据，公开使用前请使用脱敏数据，并检查输出文件中的患者信息。

## 6. 环境

- MATLAB：建议使用支持 `timetable`、`readmatrix`、并行池和项目中所用信号处理函数的版本。
- Python：NumPy、pandas、h5py、scikit-learn、joblib、tqdm、imbalanced-learn。
- C：标准 C99 + `<math.h>`；板级环境为 ALIENTEK STM32F429（HAL/FATFS/SDRAM），PC 端可用任何支持 C99 的编译器复测算法单元。

参数来源、版本差异和未复制内容见 `05_文档`。
