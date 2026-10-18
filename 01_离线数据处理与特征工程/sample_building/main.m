%% ============================================================
% 一体化离线训练数据生成代码
% ============================================================

clear;
clc;

%% 1. 路径配置

rootFolder = 'G:\TJX\新整理的在线算法\data';
infoFile = 'G:\TJX\新整理的在线算法\info\S31.mat';
outputFolder = 'G:\TJX\新整理的在线算法\alltrain180';

if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

load(infoFile, 'S31');

fprintf('S31 大小：%d × %d\n', size(S31,1), size(S31,2));


%% 2. 遍历原始数据并生成训练数据
%
% 不保存 *_marked.mat
% 不动态扩展 trainingData/trainingLab
% 使用 cell 暂存每个文件的数据，最后一次性拼接

total_files_processed = 0;
total_files_skipped = 0;
fileCounter = 1;

allFeatures = {};
allLab = {};
blockCount = 0;

for i = 1:size(S31,1)

    patientName = S31{i,1};

    if size(S31,2) > 1
        hospitalName = S31{i,2};
    else
        hospitalName = '未知医院';
    end

    patientFolder = ...
        fullfile(rootFolder,hospitalName,patientName);

    if ~exist(patientFolder,'dir')
        total_files_skipped = total_files_skipped + 1;
        continue;
    end

    % 优先寻找 data 子目录
    subDataFolder = fullfile(patientFolder,'data');

    if exist(subDataFolder,'dir')
        files = dir(fullfile(subDataFolder,'*_processed*.mat'));
    else
        files = dir(fullfile(patientFolder,'*_processed*.mat'));
    end

    if isempty(files)
        total_files_skipped = total_files_skipped + 1;
        continue;
    end

    for j = 1:length(files)

        sourceFile = fullfile(files(j).folder,files(j).name);
        data = load(sourceFile);

        % 检查必要字段
        if ~isfield(data,'features') || ...
           ~isfield(data,'bad_samples') || ...
           ~isfield(data,'label_index') || ...
           ~isfield(data,'time_series')
        
            total_files_skipped = total_files_skipped + 1;
            continue;
        end

        features = data.features;
        bad_samples = data.bad_samples;
        label_index = data.label_index;
        time_series = data.time_series;


        %% 降采样

        window_length = 6;
        step_size = 1;

        samples_count = size(features,1);

        % 第2、4、6、8...个样本
        downsample_idx = 1:2:samples_count;

        new_samples_count = length(downsample_idx);

        features_remove = features(downsample_idx,:);


        %% 初始化 lab

        lab = zeros(new_samples_count,7);

        % 第7列：文件编号
        lab(:,7) = fileCounter;

        % 第2列：患者编号
        lab(:,2) = i;

        % 第3列：健康/患者
        if contains(hospitalName,'健康P1')
            lab(:,3) = 0;
        else
            lab(:,3) = 1;
        end

        % 第6列：质量标记
        % 0 = 合格，1 = 不合格
        lab(:,6) = ismember(downsample_idx,bad_samples);


        %% 第1列：发作标签
        % 第4列：时间 HHMMSS

        for l = 1:new_samples_count

            orig_idx = downsample_idx(l);

            start_time = ...
                (orig_idx - 1) * step_size + 1;

            end_time = ...
                start_time + window_length - 1;

            if end_time <= size(label_index,1) && ...
               end_time <= size(time_series,1)

                if label_index(end_time,1) == 1
                    lab(l,1) = 1;
                else
                    lab(l,1) = 0;
                end

                % 第4列
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


        %% 暂存当前文件数据

        blockCount = blockCount + 1;

        allFeatures{blockCount} = features_remove;
        allLab{blockCount} = lab;

        total_files_processed = total_files_processed + 1;
        fileCounter = fileCounter + 1;

    end
end


%% 3. 一次性拼接全部训练数据

if isempty(allFeatures)
    error('没有任何有效数据，无法生成训练集。');
end

fprintf('\n开始拼接训练数据...\n');

trainingData = vertcat(allFeatures{:});
trainingLab = vertcat(allLab{:});

clear allFeatures allLab;

fprintf('训练数据大小：%d × %d\n', ...
    size(trainingData,1),size(trainingData,2));

fprintf('训练标签大小：%d × %d\n', ...
    size(trainingLab,1),size(trainingLab,2));


%% 4. FCM 聚类
%
% 只使用第6列=0的合格样本
% FCM使用第1、10列特征
% 聚类结果写入trainingLab第5列

fprintf('\n开始 FCM 聚类...\n');

valid_samples = trainingLab(:,6) == 0;

fprintf('合格样本：%d / %d\n', ...
    sum(valid_samples),size(trainingLab,1));

selected_features = ...
    trainingData(valid_samples,[1,10]);

true_labels = ...
    trainingLab(valid_samples,1);


%% FCM 专用 Z-score

fcm_mean = mean(selected_features,1);
fcm_std = std(selected_features,0,1);

fcm_std(fcm_std == 0) = 1;

normalized_features = ...
    (selected_features - fcm_mean) ./ fcm_std;


%% FCM 参数

Cn = 2;
b = 1.2;
maxIter = 1000;
minobj = 1e-5;

[~,center,U,~] = fuzzyCMeans( ...
    normalized_features, ...
    Cn, ...
    b, ...
    maxIter, ...
    minobj);


%% 判断高运动聚类

distances = sqrt(sum(center.^2,2));

[~,sorted_idx] = sort(distances,'ascend');

high_motion_cluster = sorted_idx(2);

U = U';


%% 根据隶属度重新分配运动标签

reassigned_idx = zeros(size(U,2),1);

reassigned_idx( ...
    U(high_motion_cluster,:) > 0.5) = 1;

reassigned_idx( ...
    U(high_motion_cluster,:) <= 0.5) = 0;


%% 更新 trainingLab 第5列

trainingLab(valid_samples,5) = reassigned_idx;


%% 5. FCM 评价指标

TP = sum(reassigned_idx == 1 & true_labels == 1);
FP = sum(reassigned_idx == 1 & true_labels == 0);
TN = sum(reassigned_idx == 0 & true_labels == 0);
FN = sum(reassigned_idx == 0 & true_labels == 1);

precision = TP / max(TP + FP,1);
recall = TP / max(TP + FN,1);

f1_score = ...
    2 * precision * recall / ...
    max(precision + recall,1);

accuracy = ...
    (TP + TN) / ...
    max(TP + TN + FP + FN,1);

fprintf('\nFCM结果：TP=%d, FP=%d, TN=%d, FN=%d\n', ...
    TP,FP,TN,FN);

fprintf('Precision=%.4f，Recall=%.4f，F1=%.4f，Accuracy=%.4f\n', ...
    precision,recall,f1_score,accuracy);


%% 6. 保存 FCM 参数

save( ...
    fullfile(outputFolder,'normalization_params.mat'), ...
    'fcm_mean','fcm_std');

save( ...
    fullfile(outputFolder,'center.mat'), ...
    'center');


%% 7. 全部71维特征 Z-score

fprintf('\n计算最终71维特征归一化参数...\n');

if size(trainingData,2) ~= 71
    error('trainingData 特征维度应为71，当前为%d。', ...
        size(trainingData,2));
end

if size(trainingLab,2) ~= 7
    error('trainingLab 列数应为7，当前为%d。', ...
        size(trainingLab,2));
end

% 使用全部样本、全部71维特征
feature_mean = mean(trainingData,1);
feature_std = std(trainingData,0,1);

feature_std(feature_std == 0) = 1;

trainData = ...
    (trainingData - feature_mean) ./ feature_std;


%% 8. 保存最终归一化参数

save( ...
    fullfile(outputFolder,'feature_scaling_params.mat'), ...
    'feature_mean','feature_std');


%% 9. 保存最终数据

save( ...
    fullfile(outputFolder,'alltrain.mat'), ...
    'trainData','trainingLab','-v7.3');


%% 10. 完成

fprintf('\n处理完成！\n');
fprintf('处理文件数：%d\n',total_files_processed);
fprintf('跳过文件数：%d\n',total_files_skipped);
fprintf('最终数据大小：%d × %d\n', ...
    size(trainData,1),size(trainData,2));

fprintf('输出文件：\n');
fprintf('  normalization_params.mat\n');
fprintf('  center.mat\n');
fprintf('  feature_scaling_params.mat\n');
fprintf('  alltrain.mat\n');