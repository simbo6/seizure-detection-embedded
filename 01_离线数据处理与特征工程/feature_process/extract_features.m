function features = extract_features(segment, fs)
    % 提取加速度和角速度的幅度和频率特征，共25个特征
    % 输入:
    %   segment: 单个窗口的信号
    %   fs: 采样率
    % 输出:
    %   features: 提取的特征向量 (1x25)

    % 特征列表初始化
    features = [];
    N = length(segment);
    ma = mean(segment);
    a2 = sort(abs(segment));
    % ------ 幅度特征（13个） ------feta(2) = sqrt(sum(segment.^2)); 
    features = [features, mean(abs(segment))];                        % 1. 平均幅度
    features = [features, sqrt(sum(segment.^2))];                     % 2. 均方根
    features = [features, sqrt(mean((segment-ma).^2))];         % 6. 标准差
    features = [features, a2(round(0.25*N))];                 % 3. 25%分位数的绝对值
    features = [features, a2(round(0.5*N))];                 % 4. 50%分位数的绝对值
    features = [features, a2(round(0.75*N))];                 % 5. 75%分位数的绝对值
    features = [features, a2(round(0.75*N)) - a2(round(0.25*N))]; % 7. 四分位范围
    features = [features, sqrt(sum(diff(segment).^2))];             % 11. Jerk（加速度变化率）
    features = [features, sum(abs(diff(segment)))];              % 10. 波形长度
    features = [features, sum((abs(diff(sign(segment))) > 0) & (abs(diff(segment)) > 5)) ];% 13. 过零点数目
    features = [features, kurtosis(segment)];                    % 8. 峰度系数
    features = [features, skewness(segment)];                    % 9. 偏度系数
    SDSD = sqrt(sum(diff(segment).^2));  
    SDA = sqrt(abs(sqrt(sum(segment.^2))^2/N-ma^2));
    SD1 = sqrt(SDSD^2/2);   %SD1
    features = [features, 2*SDA^2-SD1];% 12. SD2（方差）
         


    % 提取信号的频域特征 (12个)
    % 输入: segment - 输入的窗口信号
    %       fs      - 采样频率
    % 输出:  12个频域特征的向量
     overlapT =2;
     winT=4;
     %winN = winT*fs; overlapN = overlapT*fs; nfft = winN;
     %[pxx,f] = pwelch(segment,ones(winN,1),overlapN,nfft,fs); %矩形窗，周期图
     %lenp = winT*15;

     winN = winT*fs; overlapN = overlapT*fs; nfft = 2^ceil(log2(winN));
     [pxx,f] = pwelch(segment,ones(winN,1),overlapN,nfft,fs);
     lenp = find(f<15,1,'last');
  % 频域特征
    power = sum(pxx);
    for i = 1:5
        features = [features, sum(pxx(floor(lenp/5*(i-1))+1:floor(lenp/5*i)))/power];%相对功率
    end
    % ACM 峰频及其PSD
    %cumulative_power = cumsum(pxx) / sum(pxx);
    [M,I] = sort(pxx(1:lenp),'ascend');
    features = [features, f(I(round(lenp*0.8)))];%80%上分位频率
    features = [features, f(I(round(lenp*0.9)))];%90%上分位频率
    features = [features, f(I(lenp))];%峰值频率
    features = [features, M(lenp)]; %最大PSD
    features = [features, medfreq(pxx(1:lenp),f(1:lenp))];%中值频率（重心频率）
    features = [features, meanfreq(pxx(1:lenp),f(1:lenp))];%均方频率
    features = [features, std(pxx(1:lenp))];%功率谱标准差


end
