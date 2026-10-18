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
hospitals = {'天坛医院', '宣武医院'};  % 自定义医院列表
root_folder = 'data';
output_folder = fullfile(root_folder, 'processed_data'); % 新建输出文件夹
if ~exist(output_folder, 'dir')
    mkdir(output_folder); % 创建 processed_data 文件夹
end

for i = 1:length(hospitals)
    hospital_path = fullfile(root_folder, hospitals{i});
    mat_files = find_target_mat_files(hospital_path);
    
    for j = 1:length(mat_files)
        input_filepath = mat_files{j};
        fprintf('正在处理：%s\n', input_filepath);
        
        % 加载 .mat 文件
        load(input_filepath);

        time_series = data{1,1};
        acc_data = data{2,1};
        gyr_data = data{3,1};
        emg_data = emg_removed_s;

        % 1. 去除 NaN 数据
        [time_series, acc_data, gyr_data, emg_data, label_index] = remove_nan(time_series, acc_data, gyr_data, emg_data, label);
        emg_est = ifftt(emg_data);

        % 2. 计算加速度模和角速度模
        acc_mod = compute_magnitude(acc_data);
        gyr_mod = compute_magnitude(gyr_data);

        % ==========================
        % 划分窗口处理部分
        % ==========================
        rm_values = []; % 初始化信号质量值数组
        fs_acc_gyr = 50; % 加速度/角速度采样率
        fs_emg = 200;    % 肌电信号采样率

        window_length_acc = 6 * fs_acc_gyr;  % 加速度/角速度窗口长度 (6秒)
        step_length_acc = 1 * fs_acc_gyr;    % 加速度/角速度步长 (1秒)
        window_length_emg = 6 * fs_emg;      % 肌电窗口长度 (6秒)
        step_length_emg = 1 * fs_emg;        % 肌电步长 (1秒)

        num_windows = 1 + floor((length(acc_mod) - window_length_acc) / step_length_acc); % 计算窗口数量

        rm_values = zeros(num_windows, 1); % 使用数组存储每个窗口的信号质量值

        parfor w = 1:num_windows  % 从0开始，总共num_windows个窗口
            % --- 计算加速度和角速度的索引 ---
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
            segment_emg_filtered = filter_signal(segment_emg, fs_emg, 'emg');
            
            % 肌电信号质量评估
            [~, rm_value] = signal_quality(segment_emg_filtered);
            rm_values(w) = rm_value; % 仅保存信号质量值
        end

        % ==========================
        % 保存信号质量值
        % ==========================
        [~, name, ~] = fileparts(input_filepath); % 提取文件名（不含扩展名）
        output_filename = fullfile(output_folder, [name, '_rm_values.mat']);
        save(output_filename, 'rm_values');
        
        fprintf('已处理并保存信号质量值：%s\n', output_filename);
    end
end

disp('窗口分割与信号质量值提取完成，已保存结果。');