% 清理工作区
clear; clc; close all;
% ==================== 1. 基础配置 ====================
feat_select_method = 'jmi';
% 原始路径
xunlianjiFolder = 'G:\TJX\新整理的在线算法\xunlianji{1,10}';
ceshijiFolder = 'G:\TJX\新整理的在线算法\ceshiji{1,10}';
feast_path = 'G:\TJX\新整理的在线算法\feature_select\FEAST\matlab';
mit_path = 'G:\TJX\新整理的在线算法\feature_select\MIToolbox\matlab';
featSaveRoot = 'G:\TJX\新整理的在线算法\feature_select\xunlianji_featurejmi{1,10}';
if ~exist(featSaveRoot, 'dir')
    mkdir(featSaveRoot);
end
numBins = 10;
k_values = [5,10,15,20,25,30,35,40,45,50];
balance_ratio = 10;
n_k = length(k_values);

% ==================== 存储容器 ====================
all_fold_jmi_step_scores = [];    % 5行，每行：该折完整贪心序列的jmi_scores(1:nFeat)，仅留作诊断
all_fold_joint_mi = [];           % 5行，每行：前k个特征组成的联合变量与标签的真实互信息 I(X_Sk;Y)
all_fold_rank = [];               % 5行，每一行：本折各原始特征的秩次（1=最先选）
all_fold_cv_acc = [];             % 5行，每行：各k对应的SVM CV准确率，备用

addpath(feast_path, '-begin');
addpath(mit_path, '-begin');
if ~exist('feast','file')
    error('❌ feast 未找到！请确认 FEAST\matlab 已编译（FSToolboxMex.mexw64 存在）');
end
fprintf('✅ FEAST 环境检查通过！当前使用FEAST特征选择算法：%s\n',feat_select_method);

% ==================== 3. 五折交叉验证主流程 ====================
for k_fold = 1:5
    fprintf('\n=====================================================\n');
    fprintf('开始第 %d 折交叉验证的特征选择（算法：%s）\n', k_fold,feat_select_method);
    fprintf('=====================================================\n');
    trainCrossPath = fullfile(xunlianjiFolder, [num2str(k_fold) 'cross']);
    testCrossPath = fullfile(ceshijiFolder, [num2str(k_fold) 'cross']);
    foldOutPath = fullfile(featSaveRoot, [num2str(k_fold) 'cross']);
    if ~exist(foldOutPath, 'dir')
        mkdir(foldOutPath);
    end

    % 加载数据
    fprintf('加载第 %d 折训练集数据...\n', k_fold);
    load(fullfile(trainCrossPath, 'combined_features.mat'), 'all_features');
    load(fullfile(trainCrossPath, 'combined_lab.mat'), 'all_lab');
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

    % 负类下采样
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

    % 等频离散化
    fprintf('第 %d 折正在离散化（%d 等频 bins）...\n', k_fold, numBins);
    X_discrete = zeros(size(X), 'double');
    for i = 1:size(X,2)
        q = prctile(X(:,i), linspace(0,100,numBins+1));
        q(1) = -Inf; q(end) = Inf;
        X_discrete(:,i) = discretize(X(:,i), q);
    end
    X_discrete = double(X_discrete);
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

    % ==================== FEAST双输出，获取原生JMI贪心得分与排序 ====================
    nFeat = size(X_discrete,2);
    fprintf('第 %d 折：JMI贪心全排序，读取FEAST原生JMI分步得分\n',k_fold,nFeat);
    [full_rank_idx, jmi_scores] = feast(feat_select_method, nFeat, X_discrete, y);
    % 容错：FEAST返回不足nFeat个特征，补全，补的特征JMI得分置0（最后才选）
    if length(full_rank_idx) < nFeat
        missing_feats = setdiff(1:nFeat, full_rank_idx);
        n_miss = length(missing_feats);
        full_rank_idx = [full_rank_idx, missing_feats];
        jmi_scores = [jmi_scores, zeros(1, n_miss)];
        warning('第%d折：FEAST返回排序特征不足%d个，剩余特征补至末尾，得分置0',k_fold,nFeat);
    end
    full_rank_idx = full_rank_idx(1:nFeat);
    jmi_scores = jmi_scores(1:nFeat);

    % ---- 构造本折：每个原始特征对应的秩次 rank_pos(featID)=r
    rank_pos = zeros(1,nFeat);
    for r = 1:nFeat
        feat_id = full_rank_idx(r);
        rank_pos(feat_id) = r;
    end
    all_fold_rank(k_fold,:) = rank_pos;  % 存入5折秩次矩阵

    % 保存本折完整贪心序列的JMI分步得分，仅留作诊断
    all_fold_jmi_step_scores(k_fold,:) = jmi_scores;

    % 计算前k个JMI排序特征组成的联合变量与标签之间的真实互信息：I(X_Sk;Y)
    % MIToolbox 的 mi 支持多列输入，会先将这些列编码成一个联合离散变量。
    current_fold_joint_mi = zeros(1, n_k);
    for ik = 1:n_k
        k = k_values(ik);
        subset_idx = full_rank_idx(1:k);
        current_fold_joint_mi(ik) = mi(X_discrete(:, subset_idx), y);
    end
    all_fold_joint_mi(k_fold,:) = current_fold_joint_mi;

    % ========== 遍历k，JMI选特征+SVM CV，保留指标存储（删掉单折绘图！） ==========
    selected_features = cell(n_k, 1);
    cv_accuracies = zeros(n_k, 1);
    cv_std_list = zeros(n_k, 1);
    col_K = zeros(n_k,1);
    col_FeatIdx = cell(n_k,1);
    col_CV_Acc = zeros(n_k,1);
    col_CV_Std = zeros(n_k,1);
    svm_model = @(X_train, y_train) fitcsvm(X_train, y_train, ...
        'KernelFunction','linear','Standardize',true);

    for i = 1:n_k
        k = k_values(i);
        fprintf('\n第 %d 折 - 处理 k=%d ===\n', k_fold, k);
        try
            [idx, ~] = feast(feat_select_method, k, X_discrete, y);
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

        % SVM内部5折CV
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
        fprintf('  5折CV准确率: %.4f ± %.4f\n', cv_accuracies(i), cv_std_list(i));
        col_K(i) = k;
        col_FeatIdx{i} = idx;
        col_CV_Acc(i) = cv_accuracies(i);
        col_CV_Std(i) = cv_std_list(i);
    end
    all_fold_cv_acc(k_fold,:) = cv_accuracies;
    k_detail_result = table(col_K, col_FeatIdx, col_CV_Acc, col_CV_Std,...
        'VariableNames',{'K','FeatureIndex','CV_Accuracy','CV_Std'});

    % 保存本折结果mat，不再绘制任何单折图片！
    save(fullfile(foldOutPath, 'best_features_high_motion_fold.mat'), ...
        'X','y','full_rank_idx','jmi_scores','rank_pos','cv_accuracies','k_values', ...
        'selected_features','k_detail_result','feat_select_method');
    writetable(k_detail_result, fullfile(foldOutPath, 'all_k_selected_features.csv'));
    fprintf('✅ 第 %d 折数据保存完成，本折不输出图片\n', k_fold);
end

% ==================== 全部5折跑完，只绘制两张全局汇总图 ====================
fprintf('\n=====================================================\n');
fprintf('五折全部完成，计算五折平均，绘制全局两张汇总图\n');
fprintf('=====================================================\n');

mean_joint_mi = mean(all_fold_joint_mi, 1); % 图1：五折平均真实联合互信息随k变化
mean_rank = mean(all_fold_rank,1);         % 每个特征的五折平均秩次
nFeatTotal = size(all_fold_rank,2);
% 按 1-(i-1)/N 计算重要性分数；最优为1，最末位为1/N
feat_importance = 1 - (mean_rank - 1)/nFeatTotal;

%% 图1：前k个特征组成的联合变量与标签之间的真实互信息
figure('Name','特征子集与标签的联合互信息随特征数量k变化（五折平均）');
plot(k_values, mean_joint_mi,'o-','LineWidth',2.5,'MarkerSize',7);
xlabel('特征数量 k');
ylabel('I(X_{S_k};Y)（bit，五折平均）');
title('前k个JMI排序特征组成的联合变量与标签的互信息');
grid on;
saveas(gcf, fullfile(featSaveRoot, 'JointMI_VS_K.png'));

%% 图2：不同特征的平均重要性分数（五折平均秩次归一化，论文图b）
figure('Name','不同特征的平均重要性分数');
bar(feat_importance);
xlabel('特征编号');
ylabel('特征重要性分数（五折平均秩次归一化）');
title('(b) 不同特征的平均重要性分数');
grid off;
xlim([0, nFeatTotal+1]);
saveas(gcf, fullfile(featSaveRoot, 'Avg_Feature_Importance_JMI_Rank.png'));

% 保存汇总mat
save(fullfile(featSaveRoot,'5fold_summary_jmi_result.mat'),...
    'all_fold_jmi_step_scores','all_fold_joint_mi','mean_joint_mi',...
    'all_fold_rank','mean_rank','feat_importance','all_fold_cv_acc','k_values');

fprintf('✅ 全局两张汇总图已保存到根目录 %s\n',featSaveRoot);
fprintf('  JointMI_VS_K.png：前k个JMI排序特征的联合变量与标签的真实互信息\n');
fprintf('  Avg_Feature_Importance_JMI_Rank.png：不同特征的平均重要性分数（论文图b）\n');
fprintf('  5fold_summary_jmi_result.mat：完整汇总数据\n');
fprintf('\n所有折运算结束！算法：%s\n',feat_select_method);
rmpath(feast_path);
rmpath(mit_path);
