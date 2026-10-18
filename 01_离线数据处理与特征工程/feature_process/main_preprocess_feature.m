% 主函数：main_preprocess_feature.m
% 作用：调用各个函数进行数据预处理、信号质量评估、特征提取
% 数据结构：
% data{1,1}：时间序列，单位为1s
% data{2,1}：加速度数据，50Hz
% data{3,1}：角速度数据，50Hz
% emg_removed_s：肌电数据，200Hz
% 清理环境
clc; clear; close all;

%% 参数设置
fs_acc_gyr = 50;    % 加速度和角速度采样率
fs_emg = 200;       % 肌电信号采样率
window_size = 6;    % 窗口长度（单位：秒）
overlap = 5;        % 重叠时间（单位：秒）
step_size = window_size - overlap; % 滑动步长
%% 数据准备与处理
%load('data\北京儿童医院\胡孟瑶\data'); % 替换为你的数据文件路径
%data_folder = 'data\健康P1\路佳蕾\data\';
%mat_files = dir(fullfile(data_folder, '*.mat'));

%for i = 1:length(mat_files)
    % 获取当前文件名和完整路径
    %input_filename = mat_files(i).name;
    %input_filepath = fullfile(data_folder, input_filename);
    
    % 加载 .mat 文件
 %load(input_filepath);

hospitals = {'宣武神内','宣武神外','301医院','北京儿童医院','丰台医院','健康P1','天坛医院','西交一附院神外'};  % 自定义医院列表
root_folder = 'data';
for i = 1:length(hospitals)
    hospital_path = fullfile(root_folder, hospitals{i});
    mat_files = find_target_mat_files(hospital_path);
    
    for j = 1:length(mat_files)
        input_filepath = mat_files{j};
        fprintf('正在处理：%s\n', input_filepath);
        % 添加处理代码

    
% 加载.mat文件并执行后续逻辑
load(input_filepath);

time_series = data{1,1};
acc_data = data{2,1};
gyr_data = data{3,1};
emg_data = emg_removed_s;

% 1. 去除 NaN 数据
[time_series, acc_data, gyr_data, emg_data,label_index] = remove_nan(time_series, acc_data, gyr_data, emg_data, label);
emg_est = ifftt(emg_data);
% 2. 计算加速度模和角速度模
acc_mod = compute_magnitude(acc_data);
gyr_mod = compute_magnitude(gyr_data);
% ==========================
% 划分窗口处理部分
% ==========================
features = []; % 初始化特征矩阵
fs_acc_gyr = 50; % 加速度/角速度采样率
fs_emg = 200;    % 肌电信号采样率

window_length_acc = 6 * fs_acc_gyr;  % 加速度/角速度窗口长度 (6秒)
step_length_acc = 1 * fs_acc_gyr;    % 加速度/角速度步长 (2秒)
window_length_emg = 6 * fs_emg;      % 肌电窗口长度 (6秒)
step_length_emg = 1 * fs_emg;        % 肌电步长 (2秒)

num_windows = 1 + floor((length(acc_mod) - window_length_acc) / step_length_acc); % 计算窗口数量

features = cell(num_windows, 1); % 使用单元数组存储每个窗口的特征向量
bad_samples = cell(num_windows, 1); % 使用单元数组存储不合格窗口编号
rm_values = zeros(num_windows, 1); 
parfor w = 1:num_windows  % 从0开始，总共num_windows个窗口
    % --- 计算加速度和角速度的索引 ---
    bad_samples_local = [];

    idx_acc_start = (w-1) * step_length_acc + 1;  % 当前窗口起始索引
    idx_acc_end = idx_acc_start + window_length_acc - 1; % 当前窗口结束索引
    
    % --- 计算肌电信号的索引 (4倍采样率) ---
    idx_emg_start = (w-1) * step_length_emg + 1; 
    idx_emg_end = idx_emg_start + window_length_emg - 1;

  
    
    % --- 分割当前窗口信号 ---
    segment_acc = acc_mod(idx_acc_start:idx_acc_end);  % 加速度模
    segment_gyr = gyr_mod(idx_acc_start:idx_acc_end);  % 角速度模
    segment_emg = emg_est(idx_emg_start:idx_emg_end); % 肌电信号

% --- 滤波处理 ---
segment_acc_filtered = filter_signal(segment_acc, fs_acc_gyr, 'acceleration');
segment_gyr_filtered = filter_signal(segment_gyr, fs_acc_gyr, 'angular_velocity');
% 修改处：使用 emg_removed_s 处理肌电信号
segment_emg_filtered = filter_signal(segment_emg, fs_emg,'emg');

% 肌电信号质量评估
[valid, rm_value] = signal_quality(segment_emg_filtered);
% 【新增2】将当前窗口的rm_value存入数组
if ~valid
     bad_samples_local = [bad_samples_local; w]; % 记录不合格窗口编号
    disp(['窗口 ', num2str(w), ' 的肌电信号不合格，RM = ', num2str(rm_value)]);
end
rm_values(w) = rm_value;

% --- 特征提取 ---
acc_features = extract_features(segment_acc_filtered, fs_acc_gyr);
gyr_features = extract_features(segment_gyr_filtered, fs_acc_gyr);
emg_features = extract_features_emg(segment_emg_filtered, fs_emg);

% --- 特征拼接 ---
feature_vector = [acc_features, gyr_features, emg_features];
% 保存结果到单元数组
features{w} = feature_vector;
bad_samples{w} = bad_samples_local;
end
features = vertcat(features{:}); % 合并所有窗口的特征矩阵
bad_samples = vertcat(bad_samples{:}); % 合并所有不合格样本编号
% ==========================
% 保存不合格样本编号
% ==========================
%save('bad_samples.mat', 'bad_samples');
%save('extracted_features.mat', 'features');
disp('窗口分割与特征提取完成，已保存结果。');
[~, name, ~] = fileparts(input_filepath); % 提取文件名（不含扩展名）
    output_filename = fullfile(fileparts(input_filepath), [name, '_processed.mat']);
    save(output_filename, 'features', 'bad_samples', 'label_index', 'time_series', 'rm_values');
    
    fprintf('Processed and saved: %s\n', output_filename);
% 删除原始数据文件
delete(input_filepath); % 删除原始的.mat文件
disp(['原始文件已删除: ', input_filepath]);

%[~, name, ~] = fileparts(input_filename); % 提取文件名（不含扩展名）
%output_filename = fullfile(data_folder, [name, '_processed.mat']); 
%save(output_filename, 'features', 'bad_samples', 'label_index', 'time_series');
%fprintf('Processed and saved: %s\n', output_filename);
    end
end


