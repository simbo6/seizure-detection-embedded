# MATLAB 导入与运行指南

本文说明如何把 `项目整理` 这个目录装进你本机的 MATLAB，并跑通在线回放流程。
**不需要**把任何代码复制到 MATLAB 安装目录下；所有操作都在项目目录内完成。

## 1. 环境要求

- MATLAB R2019b 或更新版本（用到 `timetable`、`readmatrix`、`parpool` 等）。
- Signal Processing Toolbox（滤波、pwelch）。
- Statistics and Machine Learning Toolbox（zscore、FCM 相关）。
- 可选：Parallel Computing Toolbox（批处理加速）。

## 2. 把项目加入 MATLAB 搜索路径

打开 MATLAB，在命令行窗口（Command Window）执行：

```matlab
projRoot = '你的项目根目录';   % 例如 D:\seizure-detection-embedded，改成你本机的实际路径

% 把在线测试目录及其所有子目录加入路径
addpath(genpath(fullfile(projRoot, '03_在线MATLAB测试')));

% 离线特征工程目录（仅在你要复现训练时才需要）
addpath(genpath(fullfile(projRoot, '01_离线数据处理与特征工程')));
```

> 中文路径在 MATLAB R2019a 及以上一般没问题；如果出现中文乱码或路径识别失败，
> 可以把整个 `项目整理` 文件夹复制到一个纯英文路径（例如 `D:\epil_project\`），
> 再把 `projRoot` 指过去。

### 永久生效（可选）

把上面两行 `addpath(...)` 写进 `startup.m`（放在 MATLAB 的用户启动目录下），
以后每次启动 MATLAB 自动加载。查看启动目录：

```matlab
userpath
```

## 3. 配置数据路径

打开 `03_在线MATLAB测试/1_Main/online_project_config.m`，改三处：

| 字段 | 含义 | 示例 |
|---|---|---|
| `data_root` | 脱敏 MAT 数据所在目录 | `'D:\epil_data\patient_mat\'` |
| `fold_info_file` | 五折划分信息文件 | `'D:\epil_data\fold_info.csv'` |
| `true_events_file` | 真实发作事件标注 | `'D:\epil_data\true_events.xlsx'` |

模型参数目录**不用改**——`setup_online_detector_paths` 会自动指到项目内的
`04_模型参数/`。

如果只是想先跑通流程、暂时没有真实数据，可以先用一两个脱敏 MAT 文件测试。

## 4. 跑通在线回放

```matlab
% 1. 切到在线主目录
cd(fullfile(projRoot, '03_在线MATLAB测试', '1_Main'));

% 2. 初始化路径
root = fileparts(pwd);                 % 指向 03_在线MATLAB测试 根
addpath(fullfile(root, '0_Utils'));
setup_online_detector_paths(root);

% 3. 单文件回放（fold=1 用第 1 折的模型参数）
out = run_online_pipeline('你的MAT文件路径.mat', 1);

% 4. 批量回放（可选）
% out = run_batch_evaluation(projRoot, 1);
```

运行成功后会在输出目录看到：
- `points.csv`：逐窗口的 SVM 分数与是否超阈。
- `events.xlsx`：合并后的发作事件列表。
- `result.mat`：完整状态结构，用于事后画图或与 C 端输出对齐。

更详细的入参/出参见 `03_在线MATLAB测试/1_Main/README_运行接口.md`。

## 5. 复现离线训练（可选）

如果你要重新跑 Python 训练而不是用现成的 `04_模型参数/`：

1. 在 Python 环境里装好依赖：
   ```bash
   pip install -r 02_Python训练与后处理/requirements.txt
   ```
2. 按 `02_Python训练与后处理/svm/cross_train.py` 头部注释配置数据路径。
3. 训练完成后把 `w.npy / b.npy / norm_params_fold*.mat / fcm_params.mat / center.mat`
   回写到 `04_模型参数/` 对应子目录，再回到第 4 步跑 MATLAB 在线。

## 6. 切换 fold / 特征数量 / 模型

所有实验配置都集中在 `online_project_config.m`：

- **换 fold**：把 `run_online_pipeline('xxx.mat', k)` 的 `k` 改成 1–5。
- **换特征数**：修改 config 里的 `n_features`，并确保 `04_模型参数/feature_selection/<k>cross/all_k_selected_features.csv` 存在对应行数。
- **换滤波档**：config 里的 `filter_level`（2/4/6）对应 `04_模型参数/svm_2_filter`、`svm_4_filter`、`svm_6_filter`。当前默认交付的是 `svm_6_filter`。

## 7. 与 C 端对齐验证（推荐）

如果要把 MATLAB 输出和 STM32 输出做逐点比对：

1. 选一段脱敏数据，先用 MATLAB 跑一遍，把每秒的 `fit` 值导出成 CSV。
2. 把同一段数据转成 C 端 `test.c` 期望的 txt 格式，烧到 SD 卡跑板。
3. 对比两端的 `fit` 序列。允许存在 < 1e-3 的浮点误差；如果差异显著，
   先检查 `EpilAlgo1.c` 里硬编码的 `PS1_mean / PS2_mean / w / b_model` 是否
   与 `04_模型参数/` 当前 fold 的值一致。

## 8. 常见问题

| 现象 | 排查 |
|---|---|
| `Undefined function 'setup_online_detector_paths'` | 没跑第 2 步的 `addpath`，或路径里包含未转义的中文。 |
| 找不到 `w.npy` / `center.mat` | `04_模型参数/` 里对应 fold 目录缺失，回到第 5 步补训练。 |
| `readmatrix` 报错 | MATLAB 版本太老，升级到 R2019b+。 |
| 特征编号越界 | 1-based vs 0-based 混淆，见 `README.md` 第 5 节。 |
| 结果全是 NaN | 检查数据采样率是否为 ACC/GYR=50 Hz、EMG=200 Hz，以及 EMG SQI 阈值。 |
