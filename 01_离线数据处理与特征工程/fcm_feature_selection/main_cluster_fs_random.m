function [indexF1, cluster, rank_feature, feature_rank, feature_lscore] = main_cluster_fs_random(trainset, trainlab, fnums, clusters, savefile)
    % ===================== 只需修改这里切换划分段数 =====================
    fold_num = 30;  
    % ====================================================================
    
    % 特征选择与参数寻优结果初始化
    n_features = size(trainset, 2);
    feature_lscore = zeros(fold_num, n_features);  % Laplacian score
    feature_rank = zeros(fold_num, n_features);    % 特征排序，第 i 个特征的秩次
    rank_feature = zeros(fold_num, n_features);    % 特征排序，第 i 个秩次对应的特征索引

    % 将整个训练集随机均等划分为 fold_num 个子集。
    % 每个样本只属于一个子集，不使用标签参与划分。
    N = size(trainset, 1);
    random_order = randperm(N);
    subset_idx = cell(1, fold_num);
    for j = 1:fold_num
        subset_idx{j} = random_order(j:fold_num:end);
    end

    % 重复 fold_num 次样本抽样
    SC = zeros(fold_num, max(fnums), max(clusters)); % 轮廓系数存储
    res = zeros(fold_num, max(fnums), max(clusters), 10); % 性能指标存储
    method = "FCM";
    for sample = 1:fold_num
        fprintf('\n第 %d 个抽样：\n', sample)

        % 使用第 sample 个随机等分子集；标签仅用于额外性能统计
        current_idx = subset_idx{sample};
        trainset_sample = trainset(current_idx, :);
        trainlabel_sample = trainlab(current_idx, 1);

        % 计算 Laplacian score
        tic;
        [rank_feature(sample, :), feature_lscore(sample, :)] = fsulaplacian(trainset_sample, 'NumNeighbors', 10, 'KernelScale', 'auto');
        feature_rank(sample, rank_feature(sample, :)) = 1:n_features;  % 特征秩次
        fprintf('计算Laplacian分数耗时 %.0f秒\n', toc);
        fprintf(['特征重要性排序为：',repmat('%d ',1,n_features),'\n'],rank_feature(sample,:))

        % 网格搜索
        for fnum = fnums
            trainset_fnum = trainset_sample(:, rank_feature(sample, 1:fnum));
            for cluster = clusters
                hyperparas = struct('K',cluster,'b',1.2);
                tic;[~,predj] = trainModel(trainset_fnum,[],method,hyperparas);
                fprintf('FCM模型 (%d, %d) 训练耗时：%.0f秒，',fnum,cluster,toc)
                tic; s = silhouette(trainset_fnum, predj, "sqEuclidean");
                SC(sample, fnum, cluster) = mean(s);
                fprintf('SC计算耗时：%.0f秒，',toc)
                res(sample, fnum, cluster, :) = evaSample(trainlabel_sample == 1, predj ~= 0, 1, 0);
                fprintf('SC = %.4f, TP = %d, FN = %d, FP = %d, TN = %d, SENS = %.2f, SPE = %.4f, SEL = %.2f, ACC = %.4f\n',SC(sample,fnum,cluster),res(sample,fnum,cluster,[1:4 7:8 6 5]))
            end
        end
    end

    % 计算平均特征秩次和最佳参数
    mean_row = fold_num + 1; % 均值放在最后一行
    feature_rank(mean_row, :) = mean(feature_rank, 1);  % 平均秩次
    [~, rank_feature(mean_row, :)] = sort(feature_rank(mean_row, :), 'ascend');  % 平均重要性排序

    SC_mean = squeeze(mean(SC, 1));  % 平均轮廓系数
    [~, fnum_cluster] = maxMatrix(SC_mean);  % 找到最大 SC 对应的 fnum 和 cluster
    feature_selected_count = fnum_cluster(1);
    cluster = fnum_cluster(2);
    indexF1 = rank_feature(mean_row, 1:feature_selected_count);  % 选择特征

    % 保存结果
    save(savefile, 'SC', 'indexF1', 'cluster', 'feature_lscore', 'feature_rank', 'rank_feature', 'res');
end