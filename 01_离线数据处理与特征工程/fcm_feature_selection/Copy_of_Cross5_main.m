clc; close all; clear

% 添加函数路径
addpath(genpath('function'));

%% =========================
% 路径设置
%% =========================

outputFolder = 'G:\TJX\新整理的在线算法\cross_output';

modelFolder = fullfile(...
    'G:\TJX\新整理的在线算法\fcm_featrue_select',...
    'models1no_filter');


if ~exist(modelFolder,'dir')
    mkdir(modelFolder);
end


%% =========================
% 参数设置
%% =========================

fnums = 1:5;

clusters = 2;

threshold = 0;
%% =========================
% 获取Fold文件
%% =========================

foldFiles = cell(1,5);

featureCols = 0;

labCols = 0;

for fold = 1:5

    foldPath = fullfile(outputFolder,...
        ['Fold' num2str(fold)]);

    files = dir(fullfile(foldPath,'*_marked.mat'));

    if ~isempty(files)

        foldFiles{fold}=arrayfun(@(x)...
            fullfile(foldPath,x.name),...
            files,...
            'UniformOutput',false);


        if fold==1

            tempData=load(foldFiles{fold}{1});

            featureCols=size(tempData.features_remove,2);

            labCols=size(tempData.lab,2);

        end

    else

        foldFiles{fold}={};

    end

end



%% =========================
% 五折交叉验证
%% =========================

for k=1:5


    fprintf('\n============================\n');
    fprintf('开始第 %d 折交叉验证\n',k);
    fprintf('============================\n');


    test_fold=k;

    train_folds=setdiff(1:5,test_fold);



    %% =========================
    % 第一次遍历
    % 统计数量
    %% =========================


    num_raw_total = 0;

    num_downsample_total = 0;

    num_quality_total = 0;

    num_after_total = 0;



    for fold=train_folds


        if isempty(foldFiles{fold})
            continue;
        end


        for f=1:length(foldFiles{fold})


            data=load(foldFiles{fold}{f});


            features=data.features_remove;

            lab=data.lab;



            %% 原始数量

            num_raw_total = num_raw_total + size(features,1);



            %% =========================
            % 非发作窗口降采样
            % 每3个取1个
            %% =========================

            neg_idx=find(lab(:,1)==0);

            pos_idx=find(lab(:,1)==1);


            neg_idx=neg_idx(1:3:end);
            pos_idx= pos_idx(1:3:end);


            keep_idx=[neg_idx;pos_idx];


            features=features(keep_idx,:);

            lab=lab(keep_idx,:);



            num_downsample_total = ...
                num_downsample_total + size(features,1);



            %% =========================
            % 质量筛选
            %% =========================

            qualified_idx = lab(:,6)==0;


            features_qualified = ...
                features(qualified_idx,:);


            lab_qualified = ...
                lab(qualified_idx,:);



            num_quality_total = ...
                num_quality_total + size(features_qualified,1);



            %% =========================
            % 阈值筛选
            %% =========================

            above_threshold_idx = ...
                features_qualified(:,1)>threshold;


            num_after_total = ...
                num_after_total + sum(above_threshold_idx);



        end

    end



    fprintf('\nFold %d 样本统计:\n',k);

    fprintf('原始样本数             : %d\n',...
        num_raw_total);

    fprintf('非发作降采样后         : %d\n',...
        num_downsample_total);

    fprintf('质量筛选后             : %d\n',...
        num_quality_total);

    fprintf('阈值筛选后             : %d\n',...
        num_after_total);




    %% =========================
    % 初始化训练集
    %% =========================


    trainset=zeros(num_after_total,...
        featureCols);


    trainlab=zeros(num_after_total,...
        labCols);


    trainRowIdx=1;




    %% =========================
    % 第二次遍历
    % 写入数据
    %% =========================


    for fold=train_folds


        if isempty(foldFiles{fold})
            continue;
        end



        for f=1:length(foldFiles{fold})


            data=load(foldFiles{fold}{f});


            features=data.features_remove;

            lab=data.lab;



            %% =========================
            % 非发作降采样
            %% =========================

            neg_idx=find(lab(:,1)==0);

            pos_idx=find(lab(:,1)==1);


            neg_idx=neg_idx(1:3:end);
            pos_idx= pos_idx(1:3:end);

            keep_idx=[neg_idx;pos_idx];


            features=features(keep_idx,:);

            lab=lab(keep_idx,:);




            %% =========================
            % 质量筛选
            %% =========================


            qualified_idx=lab(:,6)==0;


            features_qualified=features(qualified_idx,:);

            lab_qualified=lab(qualified_idx,:);




            %% =========================
            % 阈值筛选
            %% =========================


            above_threshold_idx=...
                features_qualified(:,1)>threshold;


            features_selected=...
                features_qualified(above_threshold_idx,:);


            lab_selected=...
                lab_qualified(above_threshold_idx,:);




            currRows=size(features_selected,1);



            if currRows>0


                trainset(trainRowIdx:trainRowIdx+currRows-1,:)...
                    =features_selected;


                trainlab(trainRowIdx:trainRowIdx+currRows-1,:)...
                    =lab_selected;


                trainRowIdx=trainRowIdx+currRows;


            end



        end

    end



    %% =========================
    % 去除可能多余空间
    %% =========================

    trainset=trainset(1:trainRowIdx-1,:);

    trainlab=trainlab(1:trainRowIdx-1,:);




    %% =========================
    % 标准化
    %% =========================


    trainset=trainset(:,1:50);


    trainset=zscore(trainset,0,1);


    trainlab=trainlab(:,1);



    fprintf('\n最终进入FCM:\n');

    fprintf('负样本=%d\n',sum(trainlab==0));

    fprintf('正样本=%d\n',sum(trainlab==1));




    %% =========================
    % FCM特征选择
    %% =========================


    saveFile=fullfile(modelFolder,...
        ['FCM_params_fold_' num2str(k) '.mat']);



    [indexF1,cluster]=...
        main_cluster_fs_random(...
        trainset,...
        trainlab,...
        fnums,...
        clusters,...
        saveFile);



    fprintf('\nFold %d完成:\n',k);

    fprintf('最佳特征=%s\n',...
        num2str(indexF1));

    fprintf('最佳cluster=%d\n',...
        cluster);



end



%% =========================
% 清理路径
%% =========================

rmpath(genpath('function'));

fprintf('\n所有折交叉验证完成！\n');