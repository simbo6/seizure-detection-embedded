% 功能：按照method和hyperparas的要求训练模型。
%
% 输入参数：
%     trainset：训练集，N*M double，其中N表示样本数目，M表示特征数目。
%     trainlabel：训练集标签，N*1 double，范围{-1，1}。
%     method：分类方法，1*1 string.
%     paras：超参数，struct。
%             "threshold"：.cutoff=[阈值1 阈值2 ...]，超过阈值输出1，否则输出0。
%             "iForest"：.ContaminationFraction，若为空，即为训练集中正样本的比例。
%             "kmeans"：K-聚类数目。
%             "FCM"：K-聚类数目，b-隶属度因子。默认迭代100次。
%             "DT"：决策树，MaxNumSplits-最大结点数目，MinLeafSize-最小叶结点样本量，SplitCriterion-分裂准则。
%             "KNN"：K近邻，Distance-距离度量，NumNeighbors-邻接点数目。
%             "ANN"：Activations-隐藏层激活函数，Lambda-正则化系数，LayerSizes-隐藏层大小。
%             "RF"：随机森林，n_estimator-树数目，MinLeafSize-最小叶结点样本量，NumPredictorsToSample-随机特征数目。
%             "SVM_L"：线性核SVM，cmd。
%             "SVM_RBF"：高斯核，cmd。
%             "NB"：DistributionNames，kernel。
%             "AdaBoost"：Method，Learners，NumLearningCycles，LearnRate。
%             "EasyEnsemble"：t，基分类器AdaBoost的参数Method，Learners，NumLearningCycles，LearnRate。
%
% 输出参数：
%     model：模型。threshold输出cutoff。
%     pred：N*1 矩阵，模型输出类别。threshold、iForest输出0-1，kmeans、FCM输出0-K，其余不输出。
%     fit：N*1或N*K矩阵，模型输出分数或概率。iForest输出异常分数（0-1），kmeans输出到每一类中心的距离、FCM输出隶属矩阵。
%     paras：struct，分类方法和模型超参数。

function [model,pred,fit,paras] = trainModel(trainset,trainlabel,method,paras)
    
    % 参数初始化
    pred = []; fit = [];

    % 模型训练
    paras.method = method;
    switch string(method)
        case "threshold"
            model = paras.cutoff;
            M = length(model);
            pred = sum(trainset>=model,2)==M;

        case "iForest"
%             if isempty(paras.ContaminationFraction)
                paras.ContaminationFraction = sum(trainlabel(:,1)==1)/length(trainlabel);
%             end
            [model,pred,fit] = iforest(trainset,"ContaminationFraction",paras.ContaminationFraction);
            paras.ScoreThreshold = model.ScoreThreshold;

        case "kmeans"  
            [pred,center,~,fit] = kmeans(trainset,paras.K,'MaxIter',1000);
            [pred,ids,model] = recluster(pred,center); % 聚类中心按照到原点的距离升序排列
            pred = pred-1;                             % pred默认1~cn，调整为0~cn-1
            fit = fit(:,ids);                          % fit为样本到每一个聚类中心的距离

        case "FCM"
            NumIter = 2000;
            [pred,center,fit,~] = fuzzyCMeans(trainset,paras.K,paras.b,NumIter,1e-5);
            [pred,ids,model] = recluster(pred,center);    % 聚类中心按照到原点的距离升序排列
            pred = pred-1;                                % pred默认1~cn，调整为0~cn-1
            fit = fit(:,ids);                             % fit为样本到每一个聚类中心的距离
            model(1,end+1) = paras.b;
            
        case "DT"
            model = fitctree(trainset,trainlabel(:,1),'MaxNumSplits',paras.MaxNumSplits,'MinLeafSize',paras.MinLeafSize,'SplitCriterion',paras.SplitCriterion);

        case "RF"
            M = floor(sqrt(size(trainset,2)));
            model = TreeBagger(paras.n_estimator,trainset,trainlabel(:,1),'OOBPrediction','off',...
                               'Method','classification','MinLeafSize',paras.min_sample_leaf,...
                               'NumPredictorsToSample',min([paras.max_feature M]));

        case "SVM_L"
            model = libsvmtrain(trainlabel(:,1),trainset,paras.cmd);
        
        case "SVM_RBF"
            model = libsvmtrain(trainlabel(:,1),trainset,paras.cmd);
        
        case "NB"
            model = fitcnb(trainset,trainlabel(:,1),'DistributionNames',paras.DistributionNames,'kernel', paras.Kernel); %'Width',paras.Width);
        
        case "ANN"
            model= fitcnet(trainset,trainlabel(:,1),'Activations',paras.Activations,...
                           'Lambda',paras.Lambda,'LayerSizes',paras.LayerSizes);

        case "KNN"
            model = fitcknn(trainset,trainlabel(:,1),'Distance',paras.Distance,'NumNeighbors',paras.NumNeighbors);

        case "AdaBoost"
            model = fitcensemble(trainset,trainlabel(:,1),'Method',paras.Method,'Learners',paras.Learners,...
                                 'NumLearningCycles',paras.NumLearningCycles,'LearnRate',paras.LearnRate,...
                                 'ScoreTransform','doublelogit');

        case "EasyEnsemble"
            poscount = sum(trainlabel(:,1)==1);  % 正样本数量
            negcount = length(trainlabel(:,1))-poscount; % 负样本数量
            posset = trainset(trainlabel(:,1)==1,:); % 正样本数据集
            negset = trainset(trainlabel(:,1)==-1,:); % 负样本数据集
            negset = negset(randperm(negcount),:); % 打乱顺序
            % randperm完成的是不重复的重排采样（k-permutations），如果结果中的数需要重复多次出现的情况，则可以用：randi(n,1,k)
 
            model = cell(paras.t,1);	% 这里存储模型用cell，t代表预设的adaboost模型的个数，而非每个adaboost模型里面树的数量
            
            % 开始训练t个adaboost
            for count=1:paras.t
                nset = negset(1:poscount,:); % 构建和正样本集的样本量相等的负样本集
                curtrainset = [posset;nset]; % 正样本和负样本的集合
                curtarget = zeros(size(curtrainset,1),1); % 初始化当前样本的标签集合
                curtarget(1:poscount)=1; % 将正样本设置为 1，注意这里负样本为 0

	            % 根据此数据集训练一个adaboost
                ens = fitcensemble(curtrainset,curtarget,'ScoreTransform','doublelogit',...
                                   'Method',paras.Method,'Learners',paras.Learners,...
                                   'NumLearningCycles',paras.NumLearningCycles,'LearnRate',paras.LearnRate);
                model{count} = ens;   % 保存此模型 
                negset = negset(randperm(negcount),:); % 将样本的顺序继续重新排列
            end
        otherwise
            error('错误：trainModel函数输入method不存在！')
    end

    pred = double(pred);
    fit = double(fit);
end


