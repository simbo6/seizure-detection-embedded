% EMG_Histogram_Analysis.m 最终修复版（解决小数幅值统计丢失）
clc; clear; close all;

%% ====================== 参数设置 ======================
fs_emg = 200;        % 肌电信号采样率 (Hz)
window_size = 6;     % 窗口长度 (秒)
step_size = 1;       % 滑动步长 (秒)
min_val = 0;         % 幅值最小值 (mV)
max_val  = 100;      % 幅值最大值 (mV)
bin_step = 1;        % 区间步长 (mV)
bin_edges = min_val:bin_step:max_val;  
num_bins = length(bin_edges) - 1;      

hospitals = {'天坛医院'};  
root_folder = 'S2data';    

%% ====================== 初始化全局变量 ======================
global_bin_counts = zeros(1, num_bins); 
total_files = 0;       
total_valid_windows = 0; 
total_bad_windows = 0;   
total_data_points = 0;   % 0-100mV区间内的总点数
total_window_total_points = 0; 

%% ====================== 批量处理数据 ======================
for i = 1:length(hospitals)
    hospital_path = fullfile(root_folder, hospitals{i});
    if ~exist(hospital_path, 'dir')
        fprintf('警告：路径不存在 -> %s\n', hospital_path);
        continue;
    end
    
    % 递归查找.mat文件（修复路径拼接）
    mat_files = dir(fullfile(hospital_path, '**', '*.mat'));
    mat_files_full = cell(size(mat_files));
    for k = 1:length(mat_files)
        mat_files_full{k} = fullfile(mat_files(k).folder, mat_files(k).name);
    end
    
    if isempty(mat_files_full)
        fprintf('警告：%s 下未找到.mat文件\n', hospital_path);
        continue;
    end
    
    for j = 1:length(mat_files_full)
        input_filepath = mat_files_full{j};
        total_files = total_files + 1;
        fprintf('\n========================================\n');
        fprintf('正在分析第 %d 个文件：%s\n', total_files, input_filepath);
        
        % 加载数据
        try
            load(input_filepath);
        catch ME
            fprintf('错误：加载文件失败 -> %s\n', ME.message);
            continue;
        end

        % 数据校验
        if ~exist('data', 'var') || ~iscell(data)
            fprintf('警告：数据格式不正确，跳过该文件\n');
            continue;
        end
        
        % 提取肌电数据
        try
            emg_data = data{5,1};
        catch
            fprintf('警告：data{5,1}不存在，跳过该文件\n');
            continue;
        end
        
        % 数据预处理
        emg_data = emg_data(~isnan(emg_data));  
        emg_data = emg_data(:);  
        window_length_emg = window_size * fs_emg;
        if length(emg_data) < window_length_emg
            fprintf('警告：EMG数据长度不足一个窗口，跳过该文件\n');
            continue;
        end
        
        % 计算窗口数
        step_length_emg = step_size * fs_emg;      
        num_windows = 1 + floor((length(emg_data) - window_length_emg) / step_length_emg);
        fprintf('当前文件EMG数据长度：%d 个点，可划分窗口数：%d 个\n', length(emg_data), num_windows);
        
        if num_windows <= 0
            fprintf('警告：数据长度不足，无法划分窗口\n');
            continue;
        end
        
        % 并行处理准备
        window_bin_counts = cell(num_windows, 1); 
        window_valid_flag = false(num_windows, 1);
        window_total_points = zeros(num_windows, 1);
        
        % 并行处理窗口
        parfor w = 1:num_windows
            window_bin_counts{w} = zeros(1, num_bins);
            window_valid_flag(w) = false;
            window_total_points(w) = 0;
            
            % 计算索引
            idx_emg_start = (w-1) * step_length_emg + 1;
            idx_emg_end = idx_emg_start + window_length_emg - 1;
            
            if idx_emg_end > length(emg_data)
                continue; 
            end
            
            % 提取窗口数据
            segment_emg = emg_data(idx_emg_start:idx_emg_end);
            window_total_points(w) = length(segment_emg);
            
            % 滤波+取绝对值
            segment_emg_filtered = filter_signal(segment_emg, fs_emg,'emg');
            segment_emg_filtered = abs(segment_emg_filtered);
            
            % ====================== 核心修复：浮点数区间统计 ======================
            % 方案1：用MATLAB内置histcounts函数（避免手动索引错误）
            [counts, ~] = histcounts(segment_emg_filtered, bin_edges);
            window_bin_counts{w} = counts;
            
            % （替代方案：若坚持手动计算，用以下代码）
            % valid_vals = segment_emg_filtered; % 幅值全在0-100mV，无需筛选
            % bin_indices = floor(valid_vals / bin_step) + 1;
            % bin_indices = max(min(bin_indices, num_bins), 1); % 强制限制在1-num_bins
            % for idx = bin_indices
            %     window_bin_counts{w}(idx) = window_bin_counts{w}(idx) + 1;
            % end
            
            % 调试：打印前3个窗口的幅值统计
            if w <= 3
                fprintf('窗口%d：滤波后幅值最小值=%.2f，最大值=%.2f，平均值=%.2f\n',...
                    w, min(segment_emg_filtered), max(segment_emg_filtered), mean(segment_emg_filtered));
            end
            
            window_valid_flag(w) = true;
        end
        
        % 汇总结果
        file_valid_windows = sum(window_valid_flag);
        file_bad_windows = num_windows - file_valid_windows;
        
        file_interval_points = 0;
        file_total_points = 0;
        for w = 1:num_windows
            if window_valid_flag(w) && ~isempty(window_bin_counts{w})
                global_bin_counts = global_bin_counts + window_bin_counts{w};
                file_interval_points = file_interval_points + sum(window_bin_counts{w});
                file_total_points = file_total_points + window_total_points(w);
            end
        end
        
        % 更新全局统计
        total_valid_windows = total_valid_windows + file_valid_windows;
        total_bad_windows = total_bad_windows + file_bad_windows;
        total_data_points = total_data_points + file_interval_points;
        total_window_total_points = total_window_total_points + file_total_points;
        
        fprintf('文件 %s 处理完成：\n', input_filepath);
        fprintf('  - 有效窗口：%d 个，无效窗口：%d 个\n', file_valid_windows, file_bad_windows);
        fprintf('  - 窗口内EMG总点数：%d 个\n', file_total_points);
        fprintf('  - 0-100mV区间内点数：%d 个\n', file_interval_points);
    end
end

%% ====================== 打印最终结果 ======================
fprintf('\n========================================\n');
fprintf('所有文件处理完成！\n');
fprintf('总计处理文件数：%d\n', total_files);
fprintf('总计有效窗口数：%d\n', total_valid_windows);
fprintf('总计无效窗口数：%d\n', total_bad_windows);
fprintf('总计窗口内EMG总点数：%d 个\n', total_window_total_points);
fprintf('总计0-100mV区间内点数：%d 个\n', total_data_points);

fprintf('\n========== 肌电幅值区间分布（点数）==========\n');
fprintf('区间(mV)    数据点个数\n');
fprintf('----------------------------------------\n');
for bin_idx = 1:num_bins
    bin_start = (bin_idx - 1) * bin_step;
    bin_end = bin_idx * bin_step;
    fprintf('%2d - %2d      %d\n', bin_start, bin_end, global_bin_counts(bin_idx));
end

fprintf('\n验证：所有区间点数之和 = %d（应等于0-100mV区间总点数）\n', sum(global_bin_counts));
fprintf('分析结束！\n');