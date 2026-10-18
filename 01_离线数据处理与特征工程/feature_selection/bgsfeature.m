% 清理工作区
clear; clc; close all;

% ==================== 1. 基础配置 ====================
% =====【特征选择算法名称，仅需在这里修改即可切换FEAST算法】=====
% 可选FEAST算法：'mi','mim','jmi','cmim','disr','cife','icap','releff','surprise'
feat_select_method = 'jmi';  
% ==========================================================

% 原始路径
xunlianjiFolder = 'G:\TJX\新整理的在线算法\xunlianji{1,10}';
ceshijiFolder = 'G:\TJX\新整理的在线算法\ceshiji{1,10}';
feast_path = 'G:\TJX\新整理的在线算法\feature_select\FEAST\matlab';
mit_path = 'G:\TJX\新整理的在线算法\feature_select\MIToolbox\matlab';

% 【固定输出根目录】所有结果统一存在这里
featSaveRoot = 'G:\TJX\新整理的在线算法\feature_select\xunlianji_featurejmi{1,10}';
if ~exist(featSaveRoot, 'dir')
    mkdir(featSaveRoot);
end

% 特征选择参数
numBins = 10;
k_values = [5,10,15,20,25,30,35,40,45,50];
balance_ratio = 10;
n_k = length(k_values);

% ==================== 2. 环境检查 ====================
addpath(feast_path, '-begin');
addpath(mit_path, '-begin');
if ~exist('feast','file')
    error('❌ feast 未找到！请确认 FEAST\matlab 已编译（FSToolboxMex.mexw64 存在）');
end
if ~exist('MIToolboxMex','file')
    error('❌ MIToolboxMex 未找到！请在 MIToolbox\matlab 运行 CompileMIToolbox');
end
fprintf('✅ FEAST + MIToolbox 环境检查通过！当前使用FEAST特征选择算法：%s\n',feat_select_method);

% ==================== 3. 五折交叉验证特征选择主流程 ====================
for k_fold = 1:5
    fprintf('\n=====================================================\n');
    fprintf('开始第 %d 折交叉验证的特征选择（算法：%s）\n', k_fold,feat_select_method);
    fprintf('=====================================================\n');
    
    % 原始数据读取路径
    trainCrossPath = fullfile(xunlianjiFolder, [num2str(k_fold) 'cross']);
    testCrossPath = fullfile(ceshijiFolder, [num2str(k_fold) 'cross']);
    % 当前折结果保存路径（独立文件夹：featSaveRoot/1cross、2cross...）
    foldOutPath = fullfile(featSaveRoot, [num2str(k_fold) 'cross']);
    if ~exist(foldOutPath, 'dir')
        mkdir(foldOutPath);
    end

    % 3.2 加载当前折的训练集数据
    fprintf('加载第 %d 折训练集数据...\n', k_fold);
    load(fullfile(trainCrossPath, 'combined_features.mat'), 'all_features');
    load(fullfile(trainCrossPath, 'combined_lab.mat'), 'all_lab');
    
    % 3.3 筛选高运动样本
    high_motion_idx = find(all_lab(:, 5) == 1);
    if isempty(high_motion_idx)
        warning('第 %d 折无高运动样本，跳过特征选择', k_fold);
        continue;
    end
    
    X_full = all_features(high_motion_idx, :);
    y_full = double(all_lab(high_motion_idx, 1));
    
    fprintf('第 %d 折数据筛选完成：\n', k_fold);
    fprintf('  原始训练集样本: %d | 高运动样本: %d (占比: %.1f%%)\n', ...
        size(all_features,1), size(X_full,1), 100*size(X_full,1)/size(all_features,1));
    fprintf('  特征维度：%d | 筛选后标签分布：[%.2f%% 正类] (%d 正 / %d 负)\n', ...
        size(X_full,2), 100*mean(y_full), sum(y_full==1), sum(y_full==0));
    
    % 3.4 负类下采样
    pos_idx = find(y_full == 1);
    neg_idx = find(y_full == 0);
    n_neg_sample = balance_ratio * length(pos_idx);
    n_neg_sample = min(n_neg_sample, length(neg_idx));
    neg_sample_idx = neg_idx(randsample(length(neg_idx), n_neg_sample));
    sample_idx = sort([pos_idx; neg_sample_idx]);
    
    X = X_full(sample_idx, :);
    y = y_full(sample_idx);
    
    fprintf('第 %d 折采样完成：总样本 %d (正: %d | 负: %d | 比例: %.2f%% 正类)\n', ...
        k_fold, size(X,1), sum(y==1), sum(y==0), 100*mean(y));
    
    % 3.5 等频离散化
    fprintf('第 %d 折正在离散化（%d 等频 bins）...\n', k_fold, numBins);
    X_discrete = zeros(size(X), 'double');
    for i = 1:size(X,2)
        q = prctile(X(:,i), linspace(0,100,numBins+1));
        q(1) = -Inf; q(end) = Inf;
        X_discrete(:,i) = discretize(X(:,i), q);
    end
    X_discrete = double(X_discrete);
    
    % 处理NaN/Inf
    nan_count = nnz(isnan(X_discrete));
    inf_count = nnz(isinf(X_discrete));
    fprintf('第 %d 折离散化后：NaN 数: %d | Inf 数: %d\n', k_fold, nan_count, inf_count);
    if nan_count > 0
        fprintf('警告：第 %d 折发现 NaN，进行中位数填充...\n', k_fold);
        for i = 1:size(X_discrete,2)
            med = median(X_discrete(~isnan(X_discrete(:,i)), i));
            X_discrete(isnan(X_discrete(:,i)), i) = med;
        end
    end
    if inf_count > 0
        error('❌ 第 %d 折发现 Inf 值，请检查原始数据！', k_fold);
    end
    
    cardinalities = arrayfun(@(col) length(unique(X_discrete(:,col))), 1:size(X_discrete,2));
    fprintf('第 %d 折离散化完成，特征基数范围：[%d ~ %d]\n', ...
        k_fold, min(cardinalities), max(cardinalities));
    if max(cardinalities) > 20
        warning('第 %d 折特征基数过高（>20），可能导致 FEAST 慢/不准！', k_fold);
    end
    
    % 3.6 MIM特征选择 + 交叉验证
    selected_features = cell(n_k, 1);   % 每个k对应的特征序号
    correlations_with_y = cell(n_k, 1);
    feature_correlation_matrices = cell(n_k, 1);
    cv_accuracies = zeros(n_k, 1);
    cv_std_list = zeros(n_k, 1);

    % ==========兼容旧版MATLAB：预分配数组，循环结束后再合成table，彻底规避表格行赋值报错==========
    col_K = zeros(n_k,1);
    col_FeatIdx = cell(n_k,1);
    col_MeanCorrY = zeros(n_k,1);
    col_MeanFeatCorr = zeros(n_k,1);
    col_CV_Acc = zeros(n_k,1);
    col_CV_Std = zeros(n_k,1);

    svm_model = @(X_train, y_train) fitcsvm(X_train, y_train, ...
        'KernelFunction','linear','Standardize',true);
    
    for i = 1:n_k
        k = k_values(i);
        fprintf('\n第 %d 折 - 处理 k=%d ===\n', k_fold, k);
        
        try
            % 直接使用顶部定义的feat_select_method，无需在此处硬编码jmi
            idx = feast(feat_select_method, k, X_discrete, y);
            if isempty(idx)
                warning('第 %d 折 k=%d: %s 未选出特征，切换到 Pearson 相关系数', k_fold, k,feat_select_method);
                [~, idx] = sort(abs(corr(X, y)), 'descend');
                idx = idx(1:k)';
            end
        catch e
            fprintf('第 %d 折 k=%d %s 出错：%s\n', k_fold, k,feat_select_method, e.message);
            [~, idx] = sort(abs(corr(X, y)), 'descend');
            idx = idx(1:k)';
            fprintf('切换到 fallback: 使用 corr 选前 %d 特征\n', k);
        end
        
        idx = sort(idx);
        selected_features{i} = idx;
        X_selected = X(:, idx);
        
        corr_with_y = corr(X_selected, y);
        correlations_with_y{i} = corr_with_y;
        corr_matrix = corr(X_selected);
        feature_correlation_matrices{i} = corr_matrix;
        
        % 内部5折SVM验证
        cv = cvpartition(y, 'KFold', 5);
        cv_acc = zeros(5, 1);
        for fold = 1:5
            train_idx = training(cv, fold);
            test_idx = test(cv, fold);
            mdl = svm_model(X_selected(train_idx,:), y(train_idx));
            y_pred = predict(mdl, X_selected(test_idx,:));
            cv_acc(fold) = mean(double(y_pred == y(test_idx)));
        end
        cv_accuracies(i) = mean(cv_acc);
        cv_std_list(i) = std(cv_acc);
        
        fprintf('第 %d 折 k=%d: 特征 %s\n', k_fold, k, mat2str(selected_features{i}));
        fprintf('  平均|相关系数|: %.4f\n', mean(abs(corr_with_y)));
        fprintf('  特征间平均|相关|: %.4f\n', mean(abs(corr_matrix(triu(true(k),1)))));
        fprintf('  5折CV准确率: %.4f ± %.4f\n', cv_accuracies(i), cv_std_list(i));

        % 写入数组
        col_K(i) = k;
        col_FeatIdx{i} = idx;
        col_MeanCorrY(i) = mean(abs(corr_with_y));
        col_MeanFeatCorr(i) = mean(abs(corr_matrix(triu(true(k),1))));
        col_CV_Acc(i) = cv_accuracies(i);
        col_CV_Std(i) = cv_std_list(i);
    end

    % 循环结束后一次性生成表格，全版本兼容
    k_detail_result = table(col_K, col_FeatIdx, col_MeanCorrY, col_MeanFeatCorr, col_CV_Acc, col_CV_Std,...
        'VariableNames',{'K','FeatureIndex','MeanCorrY','MeanFeatCorr','CV_Accuracy','CV_Std'});
    
    % 3.7 最优特征选取
    [best_acc, best_idx] = max(cv_accuracies);
    best_k = k_values(best_idx);
    best_features = selected_features{best_idx};
    
    fprintf('\n🎉 第 %d 折最优结果（%s算法）🎉\n', k_fold,feat_select_method);
    fprintf('最优 k: %d (CV准确率: %.4f)\n', best_k, best_acc);
    fprintf('最优特征索引: %s\n', mat2str(best_features));
    fprintf('与 y 平均相关: %.4f\n', mean(abs(correlations_with_y{best_idx})));
    fprintf('特征间平均相关: %.4f\n', mean(abs(feature_correlation_matrices{best_idx}(triu(true(best_k),1)))));
    
    X_best = X(:, best_features);

    % ==================== 3.8 全部结果保存至独立输出目录（featSaveRoot/1cross） ====================
    % 1. 主结果mat（包含所有k的特征序号、最优特征、全部指标）
    save(fullfile(foldOutPath, 'best_features_high_motion_fold.mat'), ...
        'X_best', 'y', 'best_features', 'best_k', 'high_motion_idx', 'sample_idx', ...
        'cv_accuracies', 'k_values', 'selected_features', ...
        'correlations_with_y','feature_correlation_matrices','k_detail_result','feat_select_method');
    % 将使用的特征选择算法也存入mat文件，方便后续溯源

    % 2. 额外单独保存【所有k对应的特征编号csv表格】，方便Excel查看
    writetable(k_detail_result, fullfile(foldOutPath, 'all_k_selected_features.csv'));

    % 3. 准确率曲线图
    figure('Name', sprintf('第 %d 折 CV准确率 vs 特征数', k_fold));
    plot(k_values, cv_accuracies, 'o-', 'LineWidth',3, 'MarkerSize',8);
    xlabel('特征数量 k'); ylabel('5折CV准确率');
    title(sprintf('第 %d 折 %s特征选择性能（仅高运动样本）', k_fold,feat_select_method));
    grid on; xlim([0 max(k_values)+5]);
    saveas(gcf, fullfile(foldOutPath, sprintf('cv_accuracy_k_fold%d.png', k_fold)));

    % 4. 相关性热力图
    figure('Name', sprintf('第 %d 折 最优特征相关性分析', k_fold), 'Position', [100,100,1200,500]);
    subplot(1,2,1); imagesc(correlations_with_y{best_idx}); colorbar;
    title('与 y 相关系数'); ylabel('选定特征'); clim([-1 1]);
    subplot(1,2,2); imagesc(feature_correlation_matrices{best_idx}); colorbar;
    title('特征间相关矩阵'); clim([-1 1]);
    saveas(gcf, fullfile(foldOutPath, sprintf('correlation_analysis_fold%d.png', k_fold)));
    
    fprintf('✅ 第 %d 折全部特征选择结果已保存至：%s\n', k_fold, foldOutPath);
end

% ==================== 4. 最终总结 ====================
fprintf('\n=====================================================\n');
fprintf('所有折特征选择执行完毕！使用算法：%s\n',feat_select_method);
fprintf('结果总根目录：%s\n', featSaveRoot);
fprintf('文件夹结构：1cross~5cross独立文件夹\n');
fprintf('每个折内包含文件：\n');
fprintf('  1. best_features_high_motion_fold.mat 完整结果（含全部k特征编号+所用算法名称）\n');
fprintf('  2. all_k_selected_features.csv 各k值选出特征编号表格（可直接用Excel打开）\n');
fprintf('  3. cv_accuracy_k_foldX.png 准确率折线图\n');
fprintf('  4. correlation_analysis_foldX.png 相关性热力图\n');
fprintf('=====================================================\n');

% 清理路径
rmpath(feast_path);
rmpath(mit_path);