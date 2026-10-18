% 主函数：main_preprocess_feature.m
% 作用：调用各个函数进行数据预处理、信号质量评估、特征提取
% 数据结构：
% data{1,1}：时间序列，单位为1s
% data{2,1}：加速度数据，原始100Hz（降采样后50Hz）
% data{3,1}：角速度数据，原始100Hz（降采样后50Hz）
% emg_removed_s：肌电数据，200Hz
% 清理环境
clc; clear; close all;

%% 参数设置
fs_acc_gyr = 50;    % 加速度和角速度目标采样率（降采样后）
fs_emg = 200;       % 肌电信号采样率
window_size = 6;    % 窗口长度（单位：秒）
overlap = 5;        % 重叠时间（单位：秒）
step_size = window_size - overlap; % 滑动步长

%% 数据准备与处理
hospitals = {'test1'};  % 自定义医院列表
root_folder = 'S2data';

for i = 1:length(hospitals)
    hospital_path = fullfile(root_folder, hospitals{i});
    mat_files = find_target_mat_files(hospital_path); % 需确保该函数已定义
    
    for j = 1:length(mat_files)
        input_filepath = mat_files{j};
        fprintf('正在处理：%s\n', input_filepath);

        % 加载.mat文件
        load(input_filepath);

        % 提取原始数据
        time_series = data{1,1};
        acc_data = data{2,1};  % 原始100Hz加速度数据
        gyr_data = data{3,1};  % 原始100Hz角速度数据
        emg_data = data{5,1};  % 200Hz肌电数据（无需降采样）

        % ========== 新增：降采样核心步骤 ==========
        % 将100Hz的加速度/角速度数据降采样到50Hz（每2个取1个）
        % 方法1：使用MATLAB内置downsample函数（推荐，鲁棒性强）
        acc_data = downsample(acc_data, 2);  % 降采样因子2，100Hz→50Hz
        gyr_data = downsample(gyr_data, 2);  % 降采样因子2，100Hz→50Hz
        
        % 方法2：手动索引（备选，效果同上）
        % acc_data = acc_data(1:2:end, :);  % 每2个取第1个，适配矩阵/向量
        % gyr_data = gyr_data(1:2:end, :);
        % =========================================

        % 1. 去除 NaN 数据（降采样后再清洗，避免无效计算）
        [time_series, acc_data, gyr_data, emg_data, label_index] = remove_nan(time_series, acc_data, gyr_data, emg_data, label);

        % 2. 计算加速度模和角速度模（基于降采样后的50Hz数据）
        acc_mod = compute_magnitude(acc_data);
        gyr_mod = compute_magnitude(gyr_data);

        % ==========================
        % 划分窗口处理部分
        % ==========================
        features = []; % 初始化特征矩阵
        % 注：此处fs_acc_gyr已在开头定义为50，无需重复定义
        % fs_acc_gyr = 50; 
        % fs_emg = 200;

        window_length_acc = 6 * fs_acc_gyr;  % 加速度/角速度窗口长度 (6秒)
        step_length_acc = 1 * fs_acc_gyr;    % 加速度/角速度步长 (1秒)
        window_length_emg = 6 * fs_emg;      % 肌电窗口长度 (6秒)
        step_length_emg = 1 * fs_emg;        % 肌电步长 (1秒)

        % 基于降采样后的acc_mod长度计算窗口数量，自动适配新长度
        num_windows = 1 + floor((length(acc_mod) - window_length_acc) / step_length_acc); 

        features = cell(num_windows, 1); % 使用单元数组存储每个窗口的特征向量
        bad_samples = cell(num_windows, 1); % 存储不合格窗口编号
        rm_values = zeros(num_windows, 1); 
        
        parfor w = 1:num_windows  
            bad_samples_local = [];

            % 计算加速度和角速度的索引（基于50Hz数据）
            idx_acc_start = (w-1) * step_length_acc + 1;  
            idx_acc_end = idx_acc_start + window_length_acc - 1;
            
            % 计算肌电信号的索引（200Hz，无需修改）
            idx_emg_start = (w-1) * step_length_emg + 1; 
            idx_emg_end = idx_emg_start + window_length_emg - 1;

            % 分割当前窗口信号（降采样后的50Hz数据）
            segment_acc = acc_mod(idx_acc_start:idx_acc_end);  
            segment_gyr = gyr_mod(idx_acc_start:idx_acc_end);  
            segment_emg = emg_data(idx_emg_start:idx_emg_end);

            % 滤波处理
            segment_acc_filtered = filter_signal(segment_acc, fs_acc_gyr, 'acceleration');
            segment_gyr_filtered = filter_signal(segment_gyr, fs_acc_gyr, 'angular_velocity');
            segment_emg_filtered = filter_signal(segment_emg, fs_emg,'emg');

            % 肌电信号质量评估
            [valid, rm_value] = signal_quality(segment_emg_filtered);
            if ~valid
                 bad_samples_local = [bad_samples_local; w]; 
                disp(['窗口 ', num2str(w), ' 的肌电信号不合格，RM = ', num2str(rm_value)]);
            end

            % 特征提取
            acc_features = extract_features(segment_acc_filtered, fs_acc_gyr);
            gyr_features = extract_features(segment_gyr_filtered, fs_acc_gyr);
            emg_features = extract_features_emg(segment_emg_filtered, fs_emg);

            % 特征拼接
            feature_vector = [acc_features, gyr_features, emg_features];
            features{w} = feature_vector;
            bad_samples{w} = bad_samples_local;
        end
        
        % 合并特征和不合格样本
        features = vertcat(features{:}); 
        bad_samples = vertcat(bad_samples{:}); 

        % 保存处理结果
        [~, name, ~] = fileparts(input_filepath); 
        output_filename = fullfile(fileparts(input_filepath), [name, '_processed.mat']);
        save(output_filename, 'features', 'bad_samples', 'label_index', 'time_series', 'rm_values');
        
        fprintf('Processed and saved: %s\n', output_filename);
        
        % 删除原始数据文件（可选，谨慎使用）
        % delete(input_filepath); 
        % disp(['原始文件已删除: ', input_filepath]);
    end
end