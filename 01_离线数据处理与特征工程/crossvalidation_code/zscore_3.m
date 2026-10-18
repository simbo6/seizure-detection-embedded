% 清理工作区
clear; clc; close all;

% ==================== 1. 基础配置 ====================
% 五折交叉验证数据根路径（与之前代码保持一致）
xunlianjiFolder = 'G:\TJX\新整理的在线算法\xunlianji{1,10}'; % 训练集根路径
ceshijiFolder = 'G:\TJX\新整理的在线算法\ceshiji{1,10}';     % 测试集根路径
normalizationParamFolder = 'G:\TJX\新整理的在线算法\normalization_params{1,10}'; % 归一化参数保存路径

% 【新增】归一化后整体存放根目录
xunlianjiZ_Folder = fullfile(fileparts(xunlianjiFolder), 'xunlianji_z{1,10}');
ceshijiZ_Folder = fullfile(fileparts(ceshijiFolder), 'ceshiji_z{1,10}');

% 创建各类文件夹
if ~exist(normalizationParamFolder, 'dir')
    mkdir(normalizationParamFolder);
end
if ~exist(xunlianjiZ_Folder, 'dir')
    mkdir(xunlianjiZ_Folder);
end
if ~exist(ceshijiZ_Folder, 'dir')
    mkdir(ceshijiZ_Folder);
end

% ==================== 2. 五折循环：逐折标准化 ====================
for k_fold = 1:5
    fprintf('\n=====================================================\n');
    fprintf('开始处理第 %d 折数据的归一化\n', k_fold);
    fprintf('=====================================================\n');
    
    % 2.1 定义当前折原始路径 + Z输出路径
    trainCrossPath = fullfile(xunlianjiFolder, [num2str(k_fold) 'cross']);
    testCrossPath = fullfile(ceshijiFolder, [num2str(k_fold) 'cross']);
    
    % 【新增】z版本分折文件夹
    trainCrossZ_Path = fullfile(xunlianjiZ_Folder, [num2str(k_fold) 'cross']);
    testCrossZ_Path = fullfile(ceshijiZ_Folder, [num2str(k_fold) 'cross']);
    if ~exist(trainCrossZ_Path, 'dir')
        mkdir(trainCrossZ_Path);
    end
    if ~exist(testCrossZ_Path, 'dir')
        mkdir(testCrossZ_Path);
    end
    
    % 检查原始路径是否存在
    if ~exist(trainCrossPath, 'dir')
        warning('第 %d 折训练集路径不存在：%s，跳过该折', k_fold, trainCrossPath);
        continue;
    end
    if ~exist(testCrossPath, 'dir')
        warning('第 %d 折测试集路径不存在：%s，跳过该折', k_fold, testCrossPath);
        continue;
    end
    
    % ==================== 3. 处理训练集：计算参数 + 标准化 ====================
    fprintf('第 %d 折：加载训练集数据...\n', k_fold);
    % 加载训练集原始数据（五折交叉验证保存的文件）
    train_feature_file = fullfile(trainCrossPath, 'combined_features.mat');
    train_lab_file = fullfile(trainCrossPath, 'combined_lab.mat');
    
    if ~exist(train_feature_file, 'file') || ~exist(train_lab_file, 'file')
        warning('第 %d 折训练集数据文件缺失，跳过该折', k_fold);
        continue;
    end
    
    load(train_feature_file, 'all_features'); % 训练集特征
    load(train_lab_file, 'all_lab');         % 训练集标签
    % 备份原始标签，后续要一起保存
    train_all_lab_raw = all_lab;
    
    % 筛选质量合格样本（第6列=0，与参考代码逻辑一致）
    valid_samples_train = (all_lab(:, 1) == 1 |all_lab(:, 6) == 0);
    fprintf('第 %d 折训练集：合格样本数 %d/%d\n', ...
        k_fold, sum(valid_samples_train), size(all_lab, 1));
    
    % 提取合格样本特征（仅用于计算归一化参数）
    valid_features_train = all_features(valid_samples_train, :);
    
    % 计算Z-score归一化参数（仅基于训练集合格样本）
    feature_mean = mean(valid_features_train, 1);  % 每列均值
    feature_std = std(valid_features_train, 0, 1); % 每列标准差（无偏估计，除以n-1）
    
    % 处理标准差为0的情况（避免除零错误）
    feature_std(feature_std == 0) = 1;
    
    % 对训练集所有特征进行标准化
    all_features = (all_features - feature_mean) ./ feature_std;
    
    % ========== 关键修改：删除原始cross目录下_z文件保存，只写入新z文件夹 ==========
    % 训练集归一化数据仅保存至独立xunlianji_z分折文件夹
    save(fullfile(trainCrossZ_Path, 'combined_features_z.mat'), 'all_features', '-v7.3');
    save(fullfile(trainCrossZ_Path, 'combined_lab_z.mat'), 'train_all_lab_raw', '-v7.3');
    % 也可以合并成一个特征标签文件，按需打开注释
    % save(fullfile(trainCrossZ_Path, 'combined_features_lab_z.mat'), 'all_features','train_all_lab_raw','-v7.3');
    
    % 保存归一化参数
    save(fullfile(normalizationParamFolder, sprintf('norm_params_fold%d.mat', k_fold)), ...
        'feature_mean', 'feature_std', '-v7.3');
    fprintf('第 %d 折训练集：已完成标准化，归一化数据仅保存至：%s\n', ...
        k_fold, trainCrossZ_Path);
    fprintf('第 %d 折训练集：归一化参数保存至 %s\n', ...
        k_fold, fullfile(normalizationParamFolder, sprintf('norm_params_fold%d.mat', k_fold)));
    
    % ==================== 4. 处理测试集：标准化 ====================
    fprintf('第 %d 折：加载测试集数据...\n', k_fold);
    % 加载测试集原始数据
    test_data_file = fullfile(testCrossPath, 'combined_features_lab.mat');
    if ~exist(test_data_file, 'file')
        warning('第 %d 折测试集数据文件缺失，跳过测试集处理', k_fold);
        continue;
    end
    
    load(test_data_file, 'all_features', 'all_lab'); % 测试集特征+标签
    test_all_lab_raw = all_lab;
    
    % 只用训练集的归一化参数标准化测试集
    all_features = (all_features - feature_mean) ./ feature_std;
    
    % ========== 关键修改：删除原始测试集cross目录_z存储，只存ceshiji_z ==========
    save(fullfile(testCrossZ_Path, 'combined_features_lab_z.mat'), 'all_features', 'test_all_lab_raw', '-v7.3');
    
    fprintf('第 %d 折测试集：已完成标准化，归一化数据仅保存至：%s\n', testCrossZ_Path);
    
    % ==================== 5. 数据维度校验 ====================
    % 读取新z文件夹内训练集归一化特征做维度比对
    tmp_train = load(fullfile(trainCrossZ_Path, 'combined_features_z.mat'));
    test_dim = size(all_features, 2);
    if size(tmp_train.all_features,2) ~= test_dim
        warning('第 %d 折：训练集(%d列)与测试集(%d列)特征维度不一致！', ...
            k_fold, size(tmp_train.all_features,2), test_dim);
    else
        fprintf('第 %d 折：数据维度校验通过（特征列数：%d）\n', k_fold, test_dim);
    end
    
    fprintf('✅ 第 %d 折数据处理完成！\n', k_fold);
end

% ==================== 6. 最终总结 ====================
fprintf('\n=====================================================\n');
fprintf('所有折数据处理完成！\n');
fprintf('1. 原始数据集文件夹仅保留原始mat文件，不再生成归一化_z文件\n');
fprintf('2. 归一化数据集仅存放于独立文件夹：\n');
fprintf('   训练集归一化全集：%s 内部包含1cross~5cross分折文件（特征+标签分开存储）\n',xunlianjiZ_Folder);
fprintf('   测试集归一化全集：%s 内部包含1cross~5cross分折文件\n',ceshijiZ_Folder);
fprintf('3. 归一化均值方差参数保存路径：%s\n', normalizationParamFolder);
fprintf('=====================================================\n');