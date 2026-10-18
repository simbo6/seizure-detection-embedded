% 清理工作区
clear; clc; close all;

%% ===================== 全局配置参数（特征索引统一在这里修改）=====================
feat_idx = [1,5];  % 需要选取的特征列索引，后续训练、测试集统一使用该变量
%% ==============================================================================

% 定义文件夹路径
outputFolder = 'G:\TJX\新整理的在线算法\cross_output'; % 处理后数据输出文件夹（包含 Fold1-Fold5）
xunlianjiFolder = 'G:\TJX\新整理的在线算法\xunlianji{1,5}'; % 训练集保存路径
ceshijiFolder = 'G:\TJX\新整理的在线算法\ceshiji{1,5}';     % 测试集保存路径

% 创建 xunlianji 和 ceshiji 主文件夹
if ~exist(xunlianjiFolder, 'dir')
    mkdir(xunlianjiFolder);
end
if ~exist(ceshijiFolder, 'dir')
    mkdir(ceshijiFolder);
end

% 提前获取所有Fold的文件信息（用于预分配内存）
foldFiles = cell(1, 5); % 存储每个Fold的_marked.mat文件路径
foldFeatureCols = 0;    % 特征列数（所有文件保持一致）
foldLabCols = 0;        % 标签列数（所有文件保持一致）

% 第一步：遍历所有Fold，统计文件路径和数据维度（仅执行一次，提升效率）
for fold = 1:5
    foldPath = fullfile(outputFolder, ['Fold' num2str(fold)]);
    files = dir(fullfile(foldPath, '*_marked.mat'));
    if ~isempty(files)
        % 存储当前Fold的文件路径
        foldFiles{fold} = arrayfun(@(x) fullfile(foldPath, x.name), files, 'UniformOutput', false);
        % 仅在第一次获取特征/标签的列数（假设所有文件列数一致）
        if fold == 1
            tempData = load(foldFiles{fold}{1});
            foldFeatureCols = size(tempData.features_remove, 2);
            foldLabCols = size(tempData.lab, 2);
        end
    else
        foldFiles{fold} = {};
    end
end

% 五折交叉验证
for k = 1:5
    fprintf('开始第 %d 折交叉验证\n', k);

    % 确定测试集和训练集的折
    test_fold = k;
    train_folds = setdiff(1:5, test_fold);

    % 创建当前折的保存路径
    trainCrossPath = fullfile(xunlianjiFolder, [num2str(k) 'cross']);
    testCrossPath = fullfile(ceshijiFolder, [num2str(k) 'cross']);
    if ~exist(trainCrossPath, 'dir')
        mkdir(trainCrossPath);
    end
    if ~exist(testCrossPath, 'dir')
        mkdir(testCrossPath);
    end

    % === 训练集处理（预分配内存版） ===
    % 步骤1：统计训练集所有文件的总行数（用于预分配）
    trainTotalRows = 0;
    for fold = train_folds
        if ~isempty(foldFiles{fold})
            for f = 1:length(foldFiles{fold})
                tempData = load(foldFiles{fold}{f});
                trainTotalRows = trainTotalRows + size(tempData.features_remove, 1);
            end
        end
    end

    % 步骤2：预分配训练集完整数据的内存（核心优化点）
    train_all_features = zeros(trainTotalRows, foldFeatureCols);
    train_all_lab = zeros(trainTotalRows, foldLabCols);
    trainRowIdx = 1; % 记录当前写入的行索引

    % 步骤3：遍历训练集Fold，分块写入数据（无动态扩展）
    for fold = train_folds
        if ~isempty(foldFiles{fold})
            for f = 1:length(foldFiles{fold})
                data = load(foldFiles{fold}{f});
                features = data.features_remove; % 特征数据
                lab = data.lab;                  % 标签数据

                % 获取当前文件的行数
                currRows = size(features, 1);
                % 写入预分配数组
                train_all_features(trainRowIdx:trainRowIdx+currRows-1, :) = features;
                train_all_lab(trainRowIdx:trainRowIdx+currRows-1, :) = lab;
                % 更新行索引
                trainRowIdx = trainRowIdx + currRows;
            end
        end
    end

    % --- 原逻辑：筛选符合条件的样本 ---
    qualified_idx = (train_all_lab(:, 1) == 1) | (train_all_lab(:, 6) == 0);  % 新条件
    train_qualified_features = train_all_features(qualified_idx, :);
    train_qualified_lab = train_all_lab(qualified_idx, :);

    % 保存训练集完整数据
    all_features = train_all_features;
    all_lab = train_all_lab;
    save(fullfile(trainCrossPath, 'combined_features.mat'), 'all_features', '-v7.3');
    save(fullfile(trainCrossPath, 'combined_lab.mat'), 'all_lab', '-v7.3');

    % 选择特定特征（使用顶部全局特征索引变量）
    selected_features = train_qualified_features(:, feat_idx);

    % ==================== 核心修改：Z-score归一化 ====================
    % z-score归一化（基于训练集样本计算均值和标准差）
    feature_mean = mean(selected_features, 1);  % 计算每个特征的均值
    feature_std = std(selected_features, 0, 1); % 计算每个特征的标准差（0表示除以n-1，无偏估计）
    
    % 处理标准差为0的情况（避免除以0）
    feature_std(feature_std == 0) = 1e-8; % 将0标准差替换为极小值，避免除零错误
    normalized_features = (selected_features - feature_mean) ./ feature_std;
    % =================================================================

    % 聚类参数
    Cn = 2; % 聚类数目
    b = 1.2; % 隶属度因子
    maxIter = 2000; % 最大迭代次数
    minobj = 1e-5; % 收敛阈值

    % 模糊C均值聚类
    [idx, center, U, obj_fcn] = fuzzyCMeans(normalized_features, Cn, b, maxIter, minobj);

    % 聚类中心排序
    distances = sqrt(sum(center.^2, 2));
    [~, sorted_idx] = sort(distances, 'ascend');
    illegal_cluster = sorted_idx(1); % 距离近的簇（非法样本）
    seizure_cluster = sorted_idx(2); % 距离远的簇（发作样本）

    % 重新分配聚类标签
    reassigned_idx = zeros(size(idx));
    reassigned_idx(idx == illegal_cluster) = 0;
    reassigned_idx(idx == seizure_cluster) = 1;

    % --- 修改点2: 更新符合条件的样本索引（发作样本+质量合格的非发作样本）---
    qualified_mask = (train_all_lab(:, 1) == 1) | (train_all_lab(:, 6) == 0);
    train_all_lab(:, 5) = 0; % 初始化为0
    train_all_lab(qualified_mask, 5) = reassigned_idx;

    % 保存更新后的 train_all_lab
    all_lab = train_all_lab;
    save(fullfile(trainCrossPath, 'combined_lab.mat'), 'all_lab', '-v7.3');

    % 保存Z-score归一化参数（替换原来的Min-Max参数）
    save(fullfile(trainCrossPath, 'normalization_params.mat'), 'feature_mean', 'feature_std');
    save(fullfile(trainCrossPath, 'center.mat'), 'center');


    % === 测试集处理（预分配内存版） ===
    % 步骤1：统计测试集所有文件的总行数
    testTotalRows = 0;
    if ~isempty(foldFiles{test_fold})
        for f = 1:length(foldFiles{test_fold})
            tempData = load(foldFiles{test_fold}{f});
            testTotalRows = testTotalRows + size(tempData.features_remove, 1);
        end
    end

    % 步骤2：预分配测试集完整数据的内存（核心优化点）
    test_all_features = zeros(testTotalRows, foldFeatureCols);
    test_all_lab = zeros(testTotalRows, foldLabCols);
    testRowIdx = 1; % 记录当前写入的行索引

    % 步骤3：遍历测试集Fold，分块写入数据
    if ~isempty(foldFiles{test_fold})
        for f = 1:length(foldFiles{test_fold})
            data = load(foldFiles{test_fold}{f});
            features = data.features_remove; % 特征数据
            lab = data.lab;                  % 标签数据

            % 获取当前文件的行数
            currRows = size(features, 1);
            % 写入预分配数组
            test_all_features(testRowIdx:testRowIdx+currRows-1, :) = features;
            test_all_lab(testRowIdx:testRowIdx+currRows-1, :) = lab;
            % 更新行索引
            testRowIdx = testRowIdx + currRows;
        end
    end

    % 保存测试集完整数据
    all_features = test_all_features;
    all_lab = test_all_lab;
    save(fullfile(testCrossPath, 'combined_features_lab.mat'), 'all_features', 'all_lab', '-v7.3');

    % --- 修改点3: 调整测试集筛选条件，发作样本保留，非发作样本仅质量合格 ---
    qualified_idx = (test_all_lab(:, 1) == 1) | (test_all_lab(:, 6) == 0);
    test_qualified_features = test_all_features(qualified_idx, :);

    % 选择特定特征（使用顶部全局特征索引变量）
    validation_features = test_qualified_features(:, feat_idx);

    % ==================== 核心修改：测试集使用训练集的Z-score参数归一化 ====================
    % 归一化（使用训练集的Z-score归一化参数）
    % 同样处理标准差为0的情况（保持和训练集一致）
    feature_std(feature_std == 0) = 1e-8;
    normalized_validation_features = (validation_features - feature_mean) ./ feature_std;
    % =================================================================

    % 使用训练好的模型进行聚类预测
    D = dist(center, normalized_validation_features');
    b_factor = 2 / (b - 1);
    U_validation = zeros(size(center, 1), size(normalized_validation_features, 1));
    for i = 1:size(center, 1)
        for j = 1:size(normalized_validation_features, 1)
            U_validation(i, j) = 1 / sum((D(i, j) ./ D(:, j)).^b_factor);
        end
    end

    % 分配聚类标签
    [~, validation_idx] = max(U_validation);
    validation_idx = validation_idx';

    % 重新分配测试集聚类标签
    reassigned_validation_idx = zeros(size(validation_idx));
    reassigned_validation_idx(validation_idx == illegal_cluster) = 0;
    reassigned_validation_idx(validation_idx == seizure_cluster) = 1;

    % --- 修改点4: 更新符合条件的样本索引（发作样本+质量合格的非发作样本）---
    test_all_lab(:, 5) = 0; % 初始化为0
    test_all_lab(qualified_idx, 5) = reassigned_validation_idx;

    % 保存更新后的 test_all_lab
    all_features = test_all_features;
    all_lab = test_all_lab;
    save(fullfile(testCrossPath, 'combined_features_lab.mat'), 'all_features', 'all_lab', '-v7.3');

    % === 测试集聚类结果统计 ===
    % (以下统计部分根据需求可调整，此处保持原逻辑)
    illegal_samples_test = (test_all_lab(:, 5) == 0 & qualified_idx); % 非法簇中的样本（已通过筛选）
    seizure_samples_test = (test_all_lab(:, 5) == 1); % 发作簇中的样本

    illegal_real_seizure_count_test = sum(test_all_lab(illegal_samples_test, 1) == 1);
    illegal_real_non_seizure_count_test = sum(test_all_lab(illegal_samples_test, 1) == 0);
    seizure_real_seizure_count_test = sum(test_all_lab(seizure_samples_test, 1) == 1);
    seizure_real_non_seizure_count_test = sum(test_all_lab(seizure_samples_test, 1) == 0);

    % 测试集打印聚类结果
    fprintf('Fold %d 测试集结果:\n', k);
    fprintf('  非法簇中真实发作样本数量: %d\n', illegal_real_seizure_count_test);
    fprintf('  非法簇中真实非发作样本数量: %d\n', illegal_real_non_seizure_count_test);
    fprintf('  发作簇中真实发作样本数量: %d\n', seizure_real_seizure_count_test);
    fprintf('  发作簇中真实非发作样本数量: %d\n', seizure_real_non_seizure_count_test);

    % 打印保存信息
    fprintf('Fold %d: 训练集完整数据已保存到 %s\n', k, trainCrossPath);
    fprintf('Fold %d: 测试集完整数据已保存到 %s\n', k, testCrossPath);
    fprintf('Fold %d: 聚类标签已更新并保存到 combined_lab.mat 和 combined_features_lab.mat\n', k);

end

fprintf('所有折的交叉验证完成！\n');