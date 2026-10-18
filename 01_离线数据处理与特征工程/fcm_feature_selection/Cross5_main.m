clc; close all; clear

% 添加函数路径（假设您的自定义函数在 'function' 文件夹中）
addpath(genpath('function'));

% 定义路径
outputFolder = 'F:\2026.7.30在线算法重新整理版本\离线训练\cross_output';      % 处理后数据输出文件夹（包含 Fold1-Fold5）
modelFolder = fullfile('F:\2026.7.30在线算法重新整理版本\离线训练\fcm_featrue_select', 'models'); % 模型和参数保存路径

% 创建模型文件夹
if ~exist(modelFolder, 'dir')
    mkdir(modelFolder);
end

% 参数设置
fnums = 1:5;         % 特征数目范围
clusters = 2;      % 聚类数目范围
num_subsets = 10;    % 子集数量

% 第一个特征的阈值
threshold = 0.8;

% 提前获取所有Fold的文件信息（用于预分配内存）
foldFiles = cell(1, 5);     % 存储每个Fold的_marked.mat文件路径
featureCols = 0;            % 特征列数（所有文件保持一致）
labCols = 0;                % 标签列数（所有文件保持一致）

% 第一步：遍历所有Fold，统计文件路径和数据维度（仅执行一次）
for fold = 1:5
    foldPath = fullfile(outputFolder, ['Fold' num2str(fold)]);
    files = dir(fullfile(foldPath, '*_marked.mat'));
    if ~isempty(files)
        % 存储当前Fold的文件路径
        foldFiles{fold} = arrayfun(@(x) fullfile(foldPath, x.name), files, 'UniformOutput', false);
        % 仅在第一次获取特征/标签的列数（假设所有文件列数一致）
        if fold == 1
            tempData = load(foldFiles{fold}{1});
            featureCols = size(tempData.features_remove, 2);
            labCols = size(tempData.lab, 2);
        end
    else
        foldFiles{fold} = {};
    end
end

% 五折交叉验证
for k = 1:5
    fprintf('开始第 %d 折交叉验证\n', k);

    % 确定测试集和训练集
    test_fold = k;
    train_folds = setdiff(1:5, test_fold);

    % === 预分配内存：第一步统计训练集数据维度 ===
    num_before_total = 0;  % 筛选前总数
    num_after_total = 0;   % 筛选后总数
    trainAfterTotalRows = 0; % 筛选后需要预分配的总行数
    
    % 先遍历一次，统计筛选前后的总数（用于预分配）
    for fold = train_folds
        if ~isempty(foldFiles{fold})
            for f = 1:length(foldFiles{fold})
                data = load(foldFiles{fold}{f});
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
                num_after = sum(above_threshold_idx); % 当前文件筛选后数量
                num_after_total = num_after_total + num_after; % 累加筛选后的总数
            end
        end
    end

    % === 预分配内存：初始化训练集数组 ===
    trainset = zeros(num_after_total, featureCols); % 预分配筛选后的特征数组
    trainlab = zeros(num_after_total, labCols);     % 预分配筛选后的标签数组
    trainRowIdx = 1; % 记录当前写入的行索引

    % === 合并训练集数据：分块写入预分配数组 ===
    for fold = train_folds
        if ~isempty(foldFiles{fold})
            for f = 1:length(foldFiles{fold})
                data = load(foldFiles{fold}{f});
                features = data.features_remove; % 特征数据
                lab = data.lab;                  % 标签数据
                % 只保留质量合格的样本
                qualified_idx = lab(:, 6) == 0;
                features_qualified = features(qualified_idx, :);
                lab_qualified = lab(qualified_idx, :);
                
                % 筛选第一个特征值高于阈值的样本
                above_threshold_idx = features_qualified(:, 1) > threshold;
                features_selected = features_qualified(above_threshold_idx, :);
                lab_selected = lab_qualified(above_threshold_idx, :);
                
                % 获取当前文件筛选后的行数
                currRows = size(features_selected, 1);
                if currRows > 0
                    % 写入预分配数组
                    trainset(trainRowIdx:trainRowIdx+currRows-1, :) = features_selected;
                    trainlab(trainRowIdx:trainRowIdx+currRows-1, :) = lab_selected;
                    % 更新行索引
                    trainRowIdx = trainRowIdx + currRows;
                end
            end
        end
    end
    
    % 打印每折的筛选前后总数
    fprintf('Fold %d: 阈值筛选前总样本数 = %d, 筛选后总样本数 = %d\n', k, num_before_total, num_after_total);

    % 标准化处理
    trainset = zscore(trainset(:, 1:50), 0, 1);
    trainlab = trainlab(:,1);

    % 聚类参数选择
    saveFile = fullfile(modelFolder, ['FCM_params_fold_' num2str(k) '.mat']);
    [indexF1, cluster] = main_cluster_fs(trainset, trainlab, fnums, clusters, saveFile);
    fprintf('Fold %d: 最佳特征索引 = %s, 最佳聚类数目 = %d\n', k, num2str(indexF1), cluster);
end

% 移除添加的路径（可选，保持工作区整洁）
rmpath(genpath('function'));
fprintf('所有折的交叉验证完成！\n');