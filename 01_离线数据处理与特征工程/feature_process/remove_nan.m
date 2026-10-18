function [time_seq, acc_data, gyr_data, emg_data,label_index] = remove_nan(time_seq, acc_data, gyr_data, emg_data, label)
    % 基于时间数据按秒步长处理，并删除包含 NaN 的窗口

    %% 窗口设置
    window_size_acc_gyr = 50; % 加速度/角速度每秒包含 50 个数据点
    window_size_emg = 200; % 肌电信号每秒包含 200 个数据点
    num_windows = floor(length(time_seq)); % 总秒数（窗口数量）

    % 初始化逻辑索引以标记有效窗口
    valid_windows = false(num_windows, 1);
    label_index = [];
    % 逐窗口检查
    for i = 1:num_windows
        % 当前窗口的起止索引
        start_idx_acc_gyr = (i-1) * window_size_acc_gyr + 1;
        end_idx_acc_gyr = i * window_size_acc_gyr;

        start_idx_emg = (i-1) * window_size_emg + 1;
        end_idx_emg = i * window_size_emg;

        % 检查索引范围，避免越界
        if end_idx_acc_gyr > size(acc_data, 1) || end_idx_emg > size(emg_data, 1)
            break;
        end

        % 提取当前窗口的数据
        acc_window = acc_data(start_idx_acc_gyr:end_idx_acc_gyr, :);
        gyr_window = gyr_data(start_idx_acc_gyr:end_idx_acc_gyr, :);
        emg_window = emg_data(start_idx_emg:end_idx_emg, :);

        % 检查当前窗口是否包含 NaN
        if ~any(isnan(acc_window(:))) && ~any(isnan(gyr_window(:))) && ~any(isnan(emg_window(:)))
            valid_windows(i) = true; % 标记为有效窗口
          current_label = label(i); % 获取当前窗口的 label 值
          label_index = [label_index; current_label, i]; % 记录到矩阵中
        end
    end

    % 找到有效窗口索引
    valid_idx = find(valid_windows);

    % 预分配筛选后的数据矩阵
    filtered_time = time_seq(valid_idx);
    filtered_acc = zeros(length(valid_idx) * window_size_acc_gyr, size(acc_data, 2));
    filtered_gyr = zeros(length(valid_idx) * window_size_acc_gyr, size(gyr_data, 2));
    filtered_emg = zeros(length(valid_idx) * window_size_emg, size(emg_data, 2));

    % 将有效窗口数据快速拼接到新的矩阵中
    for j = 1:length(valid_idx)
        % 当前有效窗口索引
        i = valid_idx(j);
        start_idx_acc_gyr = (i-1) * window_size_acc_gyr + 1;
        end_idx_acc_gyr = i * window_size_acc_gyr;

        start_idx_emg = (i-1) * window_size_emg + 1;
        end_idx_emg = i * window_size_emg;

        % 插入筛选后的数据
        filtered_acc((j-1)*window_size_acc_gyr+1:j*window_size_acc_gyr, :) = acc_data(start_idx_acc_gyr:end_idx_acc_gyr, :);
        filtered_gyr((j-1)*window_size_acc_gyr+1:j*window_size_acc_gyr, :) = gyr_data(start_idx_acc_gyr:end_idx_acc_gyr, :);
        filtered_emg((j-1)*window_size_emg+1:j*window_size_emg, :) = emg_data(start_idx_emg:end_idx_emg, :);
    end

    %% 更新输出
    time_seq = filtered_time;
    acc_data = filtered_acc;
    gyr_data = filtered_gyr;
    emg_data = filtered_emg;
    % 返回 label_index
    label_index = label_index;
end
