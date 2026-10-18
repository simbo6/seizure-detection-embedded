function features = extract_features_emg(segment, fs)
    % 提取肌电信号的幅度和频率特征，共21个特征
    % 输入:
    %   segment: 单个窗口的肌电信号
    %   fs: 采样率
    % 输出:
    %   features: 提取的特征向量 (1x21)

    % 特征列表初始化
    features = [];

    % ------ 幅度特征（11个） ------
   features = [features, sum(abs(segment))/length(segment)];                      % 1. EMG 积分肌电值
    features = [features, sqrt(sum(segment.^2))];                         % 2. EMG 均方根
    features = [features, sqrt(mean((segment-mean(segment)).^2))];           % 4. EMG 标准差
    features = [features, sum(segment.^2)];                      % EMG 能量
    features = [features, sum(abs(diff(segment)))];              % 5. 波形长度
    features = [features, cross_zeros(segment,50)];    % 6. 过零点
    abs_seg = abs(segment);  % 预计算绝对值，提高效率

    for i = 1:5
        if i < 5
            % 前三个特征：原逻辑，区间宽度0.4
            center = i * 0.4 - 0.2;
            count = sum(abs_seg > (center - 0.2) & abs_seg < (center + 0.2));
        else
            % 第四个特征：新区间[1.6, 90] mV
            count = sum(abs_seg >= 1.6 & abs_seg <= 90);
        end
        features = [features, count];
    end
    overlapT =2;
    winT=4;
    %winN = winT*fs; overlapN = overlapT*fs; nfft = winN;
    %[Pxx,f] = pwelch(segment,rectwin(winN),overlapN,nfft,fs);
    winN = winT*fs; overlapN = overlapT*fs; nfft = 2^ceil(log2(winN));
    [Pxx,f] = pwelch(segment,rectwin(winN),overlapN,nfft,fs);
    lenp = length(Pxx)-1;
    p = sum(Pxx(1:lenp));
      % 频域特征
    for i = 1:4
        features = [features, sum(Pxx(lenp/4*(i-1)+1:lenp/4*i))/p];  
    end   

    features = [features, medfreq(Pxx,linspace(0,fs/2,lenp+1))];           % 5. 中值频率
    features = [features, meanfreq(Pxx, f)]; % 使用 pwelch 的 f      % 6. 平均频率
    [M,I] = sort(Pxx(1:lenp),'ascend');
    %cumulative_power = cumsum(Pxx) / sum(Pxx);
    %features = [features, f(find(cumulative_power >= 0.8, 1))];%80%上分位频率
    %features = [features, f(find(cumulative_power >= 0.9, 1))];%90%上分位频率
    features = [features, f(I(round(lenp*0.8)))];                   
    features = [features, f(I(round(lenp*0.9)))];
    features = [features, f(I(lenp))];      % 9. 峰值频率
    features = [features,M(lenp)];                         % 10. 最大功率谱密度
end
