function [valid, rm_value] = signal_quality(segment)
    % 参数：
    % segment: 肌电信号数据，长度为任意200的倍数

    % 每200个数据计算一个均值
    samples_per_segment = 200; % 每段样本点数
    num_segments = length(segment) / samples_per_segment; % 分段数量

    if mod(length(segment), samples_per_segment) ~= 0
        error('输入数据长度必须是200的倍数');
    end

    % 初始化均值数组
    mean_values = zeros(1, 6); % 存储每段的均值

    % 计算每段的均值
    for i = 1:6
        start_idx = (i - 1) * samples_per_segment + 1;
        end_idx = i * samples_per_segment;
        mean_values(i) = mean(segment(start_idx:end_idx));
    end

    % 计算均值范围 RM
    rm = max(mean_values) - min(mean_values);

    % 判断信号质量
    valid = rm <= 0.02; % 70μV阈值

    % 返回 RM 值供记录使用
    rm_value = rm;
end

