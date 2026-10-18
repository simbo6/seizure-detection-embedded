function x_est = ifftt(segment_emg)
% 信号参数
y=segment_emg';
% 处理 y 中的 NaN 值，使用线性插值
nan_idx = isnan(y);
if any(nan_idx)
    % 创建非 NaN 值的索引数组
    valid_idx = find(~nan_idx);
    % 对 NaN 值进行插值
    y(nan_idx) = interp1(valid_idx, y(valid_idx), find(nan_idx), 'linear', 'extrap');
end
fs = 200;          % 采样率（Hz）
N = length(y);     % 信号长度
Y = fft(y);        % 输出信号频谱
f = (0:N-1)*(fs/N);  % 频率轴

% 已测量的频率响应（仅幅度）
f_meas = [1, 5:5:100];
gain_meas = [1, 14.40, 33.30, 61.10, 95.70, 135.40, 177.50, 219.80, 259.20, 306.90, 342.20, 382.60, 426.50, 470.20, 506.30, 535.00,553.50, 599.90, 622.90, 652.80, 600] ./ 2;
G = interp1(f_meas, gain_meas, f, 'linear');

% 计算逆增益
H_inv = zeros(size(G));
threshold = 1e-6;
H_inv(G > threshold) = 1 ./ G(G > threshold);

% 频谱处理和信号恢复
X_est = Y .* H_inv;         % 频谱除以增益
x_est = real(ifft(X_est));  % 恢复信号

