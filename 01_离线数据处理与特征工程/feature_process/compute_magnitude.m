function mod_signal = compute_magnitude(data)
    % 计算信号的模值（用于加速度和角速度）
    mod_signal = sqrt(sum(data.^2, 2));
end
