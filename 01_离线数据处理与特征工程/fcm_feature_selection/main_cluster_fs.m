function [indexF1, cluster, rank_feature, feature_rank, feature_lscore] = main_cluster_fs(trainset, trainlab, fnums, clusters, savefile)
    % 正负样本索引
    ids_0 = find(trainlab(:,1) == 0); % 负样本
    ids_1 = find(trainlab(:,1) == 1);  % 正样本

    % 特征选择与参数寻优结果初始化
    n_features = size(trainset, 2);
    feature_lscore = zeros(10, n_features);  % Laplacian score
    feature_rank = zeros(10, n_features);    % 特征排序，第 i 个特征的秩次
    rank_feature = zeros(10, n_features);    % 特征排序，第 i 个秩次对应的特征索引

    % 重复 10 次样本抽样
    SC = zeros(10, max(fnums), max(clusters)); % 轮廓系数存储
    res = zeros(10, max(fnums), max(clusters), 10); % 性能指标存储
    method = "FCM";
    for sample = 1:10
        fprintf('\n第 %d 个抽样：\n', sample)

        % 样本抽样：从负样本中抽取 1/10，与所有正样本合并
        neg_sample_idx = ids_0(sample:10:end);
        trainset_sample = [trainset(neg_sample_idx, :); trainset(ids_1, :)];
        trainlabel_sample = [trainlab(neg_sample_idx, 1); trainlab(ids_1, 1)];
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
    feature_rank(11, :) = mean(feature_rank, 1);  % 平均秩次
    [~, rank_feature(11, :)] = sort(feature_rank(11, :), 'ascend');  % 平均重要性排序

    SC_mean = squeeze(mean(SC, 1));  % 平均轮廓系数
    [~, fnum_cluster] = maxMatrix(SC_mean);  % 找到最大 SC 对应的 fnum 和 cluster
    feature_selected_count = fnum_cluster(1);
    cluster = fnum_cluster(2);
    indexF1 = rank_feature(11, 1:feature_selected_count);  % 选择特征

    % 保存结果
    save(savefile, 'SC', 'indexF1', 'cluster', 'feature_lscore', 'feature_rank', 'rank_feature', 'res');
end