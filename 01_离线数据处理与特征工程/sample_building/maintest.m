%% ============================================================
% 一体化测试集数据生成代码
%
% 功能：
% 1. 根据 W31 找到测试患者
% 2. 读取 *_processed.mat
% 3. 降采样
% 4. 生成 validationData 和 validationLab
% 5. 使用训练集的 FCM 参数进行运动分类
% 6. 使用训练集的71维 Z-score 参数进行归一化
% 7. 最终只保存 validsvm.mat
%
% 最终保存变量：
%   validData
%   validationLab
% ============================================================

clear;
clc;


%% ============================================================
% 1. 路径配置
% ============================================================

rootFolder = ...
    'G:\TJX\新整理的在线算法\data';

infoFile = ...
    'G:\TJX\新整理的在线算法\info\W31.mat';

outputFolder = ...
    'G:\TJX\新整理的在线算法\alltrain180';

% 训练阶段生成的参数文件
normalizationFile = ...
    'G:\TJX\新整理的在线算法\alltrain180\normalization_params.mat';

centerFile = ...
    'G:\TJX\新整理的在线算法\alltrain180\center.mat';

featureScalingFile = ...
    'G:\TJX\新整理的在线算法\alltrain180\feature_scaling_params.mat';

% 最终测试集文件
outputFile = ...
    fullfile(outputFolder,'validsvm.mat');


%% 创建输出文件夹

if ~exist(outputFolder,'dir')
    mkdir(outputFolder);
end


%% ============================================================
% 2. 加载 W31
% ============================================================

load(infoFile,'W31');

W31_patient_names = W31(:,1);
W31_hospitals = W31(:,2);


%% ============================================================
% 3. 遍历测试患者，生成 validationData / validationLab
%
% 注意：
% 不保存 *_marked.mat
% 使用 cell 暂存，最后一次性拼接
% ============================================================

total_files_processed = 0;
total_files_skipped = 0;

fileCounter = 1;

allFeatures = {};
allLab = {};

blockCount = 0;


%% 遍历所有医院

hospitalDirs = dir(fullfile(rootFolder,'*'));

hospitalDirs = hospitalDirs( ...
    [hospitalDirs.isdir] & ...
    ~ismember({hospitalDirs.name},{'.','..'}));


for h = 1:length(hospitalDirs)

    hospitalName = hospitalDirs(h).name;

    patientDirs = ...
        dir(fullfile(rootFolder,hospitalName,'*'));

    patientDirs = patientDirs( ...
        [patientDirs.isdir] & ...
        ~ismember({patientDirs.name},{'.','..'}));


    for p = 1:length(patientDirs)

        patientName = patientDirs(p).name;


        %% 在 W31 中寻找对应患者

        patientIndex = find( ...
            strcmp(W31_patient_names,patientName) & ...
            strcmp(W31_hospitals,hospitalName));


        if isempty(patientIndex) || ~isscalar(patientIndex)
            continue;
        end


        % W31 中患者编号
        patientID = patientIndex;


        %% 患者文件夹

        patientFolder = ...
            fullfile(rootFolder,hospitalName,patientName);

        if ~exist(patientFolder,'dir')
            total_files_skipped = ...
                total_files_skipped + 1;
            continue;
        end


        %% 查找 processed 文件

        subDataFolder = ...
            fullfile(patientFolder,'data');

        if exist(subDataFolder,'dir')

            files = dir( ...
                fullfile(subDataFolder,'*_processed*.mat'));

        else

            files = dir( ...
                fullfile(patientFolder,'*_processed*.mat'));

        end


        if isempty(files)

            total_files_skipped = ...
                total_files_skipped + 1;

            continue;
        end


        %% ====================================================
        % 处理当前患者的所有文件
        % ====================================================

        for j = 1:length(files)

            sourceFile = ...
                fullfile(files(j).folder,files(j).name);

            data = load(sourceFile);


            %% 检查必要字段

            if ~isfield(data,'features') || ...
               ~isfield(data,'bad_samples') || ...
               ~isfield(data,'label_index') || ...
               ~isfield(data,'time_series')

                total_files_skipped = ...
                    total_files_skipped + 1;

                continue;
            end


            %% 读取数据

            features = data.features;
            bad_samples = data.bad_samples;
            label_index = data.label_index;
            time_series = data.time_series;


            %% =================================================
            % 降采样
            % =================================================

            window_length = 6;
            step_size = 1;

            samples_count = size(features,1);

            % 第2、4、6、8...个样本
            downsample_idx = 1:2:samples_count;

            new_samples_count = ...
                length(downsample_idx);

            features_remove = ...
                features(downsample_idx,:);


            %% =================================================
            % 初始化 lab
            %
            % 第1列：发作标签
            % 第2列：患者编号
            % 第3列：健康/患者
            % 第4列：时间 HHMMSS
            % 第5列：运动标签（后面 FCM 更新）
            % 第6列：质量标记
            % 第7列：文件编号
            % =================================================

            lab = zeros(new_samples_count,7);


            %% 第7列：文件编号

            lab(:,7) = fileCounter;


            %% 第2列：患者编号

            lab(:,2) = patientID;


            %% 第3列：健康/患者

            if strcmp(hospitalName,'健康P1')

                lab(:,3) = 0;

            else

                lab(:,3) = 1;

            end


            %% 第6列：质量标记

            % 0 = 合格
            % 1 = 不合格

            lab(:,6) = ...
                ismember(downsample_idx,bad_samples);


            %% =================================================
            % 第1列：发作标签
            % 第4列：时间
            % =================================================

            for l = 1:new_samples_count

                orig_idx = downsample_idx(l);

                start_time = ...
                    (orig_idx - 1) * step_size + 1;

                end_time = ...
                    start_time + window_length - 1;


                if end_time <= size(label_index,1) && ...
                   end_time <= size(time_series,1)


                    %% 第1列：发作标签

                     if label_index(end_time,1) == 1
                        lab(l,1) = 1;
                    else
                        lab(l,1) = 0;
                    end


                    %% 第4列：HHMMSS

                    timeParts = sscanf( ...
                        time_series(end_time),'%d:%d:%d');


                    if length(timeParts) >= 3

                        lab(l,4) = ...
                            timeParts(1)*1e4 + ...
                            timeParts(2)*1e2 + ...
                            timeParts(3);

                    else

                        lab(l,4) = NaN;

                    end

                else

                    lab(l,4) = NaN;

                end

            end


            %% =================================================
            % 暂存当前文件
            % =================================================

            blockCount = blockCount + 1;

            allFeatures{blockCount} = ...
                features_remove;

            allLab{blockCount} = ...
                lab;


            total_files_processed = ...
                total_files_processed + 1;

            fileCounter = fileCounter + 1;

        end

    end

end


%% ============================================================
% 4. 一次性拼接测试数据
% ============================================================

if isempty(allFeatures)

    error('没有找到任何有效测试数据，无法生成验证集。');

end


validationData = ...
    vertcat(allFeatures{:});

validationLab = ...
    vertcat(allLab{:});


% 释放 cell，降低内存占用

clear allFeatures;
clear allLab;


fprintf('测试数据生成完成：%d × %d\n', ...
    size(validationData,1),size(validationData,2));


%% ============================================================
% 5. 加载训练阶段 FCM 参数
% ============================================================

load(normalizationFile, ...
    'fcm_mean','fcm_std');

load(centerFile,'center');


%% ============================================================
% 6. FCM 测试
%
% 测试集：
% 不筛选第6列
% 所有样本参与 FCM 分类
% ============================================================

valid_features = ...
    validationData(:,[1,10]);


%% 使用训练集的 FCM Z-score 参数

fcm_std(fcm_std == 0) = 1;

normalized_valid_features = ...
    (valid_features - fcm_mean) ./ fcm_std;


%% ============================================================
% 7. 根据训练得到的 center 计算 FCM 隶属度
% ============================================================

b = 1.2;

D = dist( ...
    center, ...
    normalized_valid_features');


%% 数值稳定性保护

min_dist = 1e-8;

D(D < min_dist) = min_dist;


%% FCM 隶属度

b_factor = 2/(b-1);

U_valid = zeros( ...
    size(center,1), ...
    size(normalized_valid_features,1));


for i = 1:size(center,1)

    for j = 1:size(normalized_valid_features,1)

        U_valid(i,j) = ...
            1 / sum( ...
            (D(i,j)./D(:,j)).^b_factor);

    end

end


%% 隶属度归一化

U_valid = ...
    U_valid ./ sum(U_valid,1);


%% NaN / Inf 处理

U_valid( ...
    isnan(U_valid) | isinf(U_valid)) = 0;


%% ============================================================
% 8. 自动确定高运动聚类
%
% 与训练阶段保持一致：
% 距离原点更远的聚类中心 = 高运动类别
% ============================================================

distances = ...
    sqrt(sum(center.^2,2));

[~,sorted_idx] = ...
    sort(distances,'ascend');


% 距离原点最远的 cluster

high_motion_cluster = ...
    sorted_idx(end);


%% ============================================================
% 9. 根据隶属度分配运动标签
% ============================================================

reassigned_valid_idx = ...
    zeros(size(normalized_valid_features,1),1);


reassigned_valid_idx( ...
    U_valid(high_motion_cluster,:) > 0.5) = 1;


reassigned_valid_idx( ...
    U_valid(high_motion_cluster,:) <= 0.5) = 0;


%% 更新 validationLab 第5列

validationLab(:,5) = ...
    reassigned_valid_idx;


%% ============================================================
% 10. 验证集聚类评价
% ============================================================

valid_true_labels = ...
    validationLab(:,1);


valid_accuracy = ...
    sum(reassigned_valid_idx == valid_true_labels) ...
    / numel(valid_true_labels) * 100;


TP = sum( ...
    reassigned_valid_idx == 1 & ...
    valid_true_labels == 1);

FP = sum( ...
    reassigned_valid_idx == 1 & ...
    valid_true_labels == 0);

TN = sum( ...
    reassigned_valid_idx == 0 & ...
    valid_true_labels == 0);

FN = sum( ...
    reassigned_valid_idx == 0 & ...
    valid_true_labels == 1);


fprintf('\n验证集结果：\n');

fprintf('Accuracy = %.2f%%\n', ...
    valid_accuracy);

fprintf('TP = %d, FP = %d, TN = %d, FN = %d\n', ...
    TP,FP,TN,FN);


%% ============================================================
% 11. 加载训练阶段71维特征归一化参数
% ============================================================

load(featureScalingFile, ...
    'feature_mean','feature_std');


%% ============================================================
% 12. 对全部71维特征进行 Z-score
%
% 注意：
% 必须使用训练集计算出来的 feature_mean / feature_std
% 不能重新使用测试集计算
% ============================================================

if size(validationData,2) ~= 71

    error( ...
        'validationData 特征维度应为71，当前为%d。', ...
        size(validationData,2));

end


if size(validationLab,2) ~= 7

    error( ...
        'validationLab 列数应为7，当前为%d。', ...
        size(validationLab,2));

end


feature_std(feature_std == 0) = 1;


validData = ...
    (validationData - feature_mean) ./ feature_std;


%% ============================================================
% 13. 保存最终测试集
% ============================================================

save( ...
    outputFile, ...
    'validData', ...
    'validationLab', ...
    '-v7.3');


%% ============================================================
% 14. 完成
% ============================================================

fprintf('\n测试集处理完成！\n');

fprintf('处理文件数：%d\n', ...
    total_files_processed);

fprintf('跳过文件数：%d\n', ...
    total_files_skipped);

fprintf('最终 validData 大小：%d × %d\n', ...
    size(validData,1), ...
    size(validData,2));

fprintf('最终 validationLab 大小：%d × %d\n', ...
    size(validationLab,1), ...
    size(validationLab,2));

fprintf('最终保存文件：\n');
fprintf('  validsvm.mat\n');