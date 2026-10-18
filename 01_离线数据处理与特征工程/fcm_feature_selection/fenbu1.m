clc; close all; clear

% 添加函数路径（根据您的实际情况调整路径）
addpath(genpath('function'));

% 定义数据输出文件夹路径
outputFolder = 'F:\TJX\癫痫腕表模型\train_output';

% 初始化存储第一个特征的数组
first_feature_values = [];

% 遍历所有 Fold 文件夹
    files = dir(fullfile(outputFolder, '*_marked.mat'));
    for f = 1:length(files)
        data = load(fullfile(outputFolder, files(f).name));
        features = data.features_remove; % 特征数据
        lab = data.lab;                  % 标签数据
        % 只保留质量合格的非发作样本
        qualified_non_seizure_idx = (lab(:, 6) == 0) & (lab(:, 1) == 0);
        first_feature_values = [first_feature_values; features(qualified_non_seizure_idx, 1)];
    end


% 对数据进行排序
sorted_values = sort(first_feature_values);

% 绘制折线图
figure;
plot(sorted_values, 'LineWidth', 1.5);
title('第一个特征在非发作样本中的折线图');
xlabel('样本序号');
ylabel('特征值');
grid on;