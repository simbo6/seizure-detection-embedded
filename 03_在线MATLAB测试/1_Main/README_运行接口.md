# 运行接口

所有需要人工维护的路径、特征编号、检测参数和输出命名都集中在
`online_project_config.m`。正常情况下只需要修改这一个文件。

## 单文件在线回放

```matlab
root = '你的项目根目录\03_在线MATLAB测试';
addpath(fullfile(root,'0_Utils'));
setup_online_detector_paths(root);

out = run_online_pipeline( ...
    '你的脱敏数据目录\某患者MAT文件.mat', ...
    1);
```

第二个参数可以是目录中的文件序号，也可以是准确的 MAT 文件名。
默认结果保存到项目的 `results` 目录。

## 批量运行

```matlab
batch = run_batch_evaluation();      % 使用统一配置中的特征数量
batch = run_batch_evaluation(25);    % 明确使用25个特征
```

## 明确接口

- `online_project_config`：统一项目配置。
- `load_patient_raw_record`：患者原始 MAT 数据读取接口。
- `epilepsy_external_model`：模型、归一化参数及特征编号加载接口。
- `run_patient_raw_demo`：单个文件的2秒在线回放接口。
- `run_online_pipeline`：单文件运行并统一保存结果的推荐入口。
- `run_batch_evaluation`：全数据集批处理入口。

输出名统一为：

```text
医院__患者__源文件__foldXX__kXX__profile__result.mat
医院__患者__源文件__foldXX__kXX__profile__points.csv
医院__患者__源文件__foldXX__kXX__profile__events.xlsx
```
