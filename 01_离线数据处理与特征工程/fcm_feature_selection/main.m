clc; close all; clear

% 添加函数路径（假设您的自定义函数在 'function' 文件夹中）
addpath(genpath('function'));

% 定义路径
outputFolder = 'E:\matlab\S2traintest\all_output';      % 处理后数据输出文件夹（包含 Fold1-Fold5）
modelFolder = fullfile('E:\matlab\S2traintest\juleicanshu', 'models'); % 模型和参数保存路径

% 创建模型文件夹
if ~exist(modelFolder, 'dir')
    mkdir(modelFolder);
end

% 参数设置
fnums = 1:5;         % 特征数目范围
clusters = 2;      % 聚类数目范围
num_subsets = 10;    % 子集数量

% 第一个特征的阈值
threshold = 0.75;

% 五折交叉验证

    % 合并训练集数据
    trainset = [];
    trainlab = [];
    num_before_total = 0;  % 筛选前总数
    num_after_total = 0;   % 筛选后总数
    
        files = dir(fullfile(outputFolder, '*_marked.mat'));
        for f = 1:length(files)
            data = load(fullfile(outputFolder, files(f).name));
            features = data.features_remove; % 特征数据
            lab = data.lab;                  % 标签数据
            % 只保留质量合格的样本
            qualified_idx = lab(:, 6) == 0;
            features_qualified = features(qualified_idx, :);
            lab_qualified = lab(qualified_idx, :);
            
            % 累加筛选前的总数
            num_before_total = num_before_total + size(features_qualified, 1);
            
            % 筛选第一个特征值高于阈值的样本
            above_threshold_idx = features_qualified(:, 1) > threshold;
            num_after_total = num_after_total + sum(above_threshold_idx); % 累加筛选后的总数
            
            trainset = [trainset; features_qualified(above_threshold_idx, :)];
            trainlab = [trainlab; lab_qualified(above_threshold_idx, :)];
        end
    
    % 打印每折的筛选前后总数
    fprintf(' 阈值筛选前总样本数 = %d, 筛选后总样本数 = %d\n',  num_before_total, num_after_total);

    % 标准化处理
%   trainset = zscore(trainset(:, [1,3:25]), 0, 1);
    trainset = zscore(trainset(:, 1:50), 0, 1);
    trainlab = trainlab(:,1);

    % 聚类参数选择
    saveFile = fullfile(modelFolder, 'FCM_params_fold.mat');
    [indexF1, cluster] = Copy_of_main_cluster_fs(trainset, trainlab, fnums, clusters, saveFile);
    fprintf('最佳特征索引 = %s, 最佳聚类数目 = %d\n',  num2str(indexF1), cluster);
