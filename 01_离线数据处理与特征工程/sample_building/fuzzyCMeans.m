function [idx, center, U, obj_fcn] = fuzzyCMeans(X, Cn, b, maxIter, minobj)
    % 初始化样本数和隶属矩阵
    N = size(X, 1); % 样本数
    U = randn(Cn, N); % 初始化隶属矩阵
    U = abs(U) ./ sum(abs(U), 1); % 归一化
    
    % 计算初始的隶属矩阵幂和聚类中心
    U2 = U.^b;
    center = iterCenter(U2, X, Cn);
    
    % 计算初始距离矩阵和目标函数值
    D = computeEuclideanDist(center, X); % 欧氏距离计算
    obj_fcn(1, 1) = sum(U2 .* D, 'all');
    
    % 更新隶属矩阵
    U = iterU(X, center, b);
    
    % 迭代过程
    for i = 2:maxIter
        U0 = U;
        Ub = U0.^b; % 修正隶属矩阵
        
        % 更新聚类中心和隶属矩阵
        center = iterCenter(Ub, X, Cn); 
        U = iterU(X, center, b); 
        
        % 计算新的距离矩阵和目标函数值
        D = computeEuclideanDist(center, X);
        obj_fcn(i, 1) = sum(Ub .* (D.^2), 'all');
        
        % 判断是否收敛
        if max(abs(U - U0), [], 'all') < minobj
            [~, idx] = max(U);
            idx = idx';
            U = U'; % 转置为一列一类
            return;
        end
    end
    
    % 如果未收敛，输出警告
    warning(['FCM在迭代', num2str(maxIter), '次后未收敛。']);
end

% 计算聚类中心
function center = iterCenter(U2, X, Cn)
    M = size(X, 2);
    center = zeros(Cn, M);
    for i = 1:Cn
        center(i, 1:M) = sum(U2(i, :)' .* X, 1) / sum(U2(i, :)); % 更新聚类中心
    end
end

% 计算欧氏距离
function D = computeEuclideanDist(center, X)
    % 输入中心矩阵 (Cn x M) 和样本矩阵 (N x M)
    % 输出距离矩阵 (Cn x N)
    Cn = size(center, 1);
    N = size(X, 1);
    D = zeros(Cn, N);
    for i = 1:Cn
        D(i, :) = sqrt(sum((X - center(i, :)).^2, 2))'; % 欧氏距离公式
    end
end

% 更新隶属矩阵
function U = iterU(X, center, b)
    % 计算欧氏距离
    D = computeEuclideanDist(center, X);
    b = 2 / (b - 1); % 转换模糊因子
    Cn = size(center, 1);
    N = size(X, 1);
    U = zeros(Cn, N);
    
    % 更新隶属矩阵
    for i = 1:Cn
        for j = 1:N
            U(i, j) = 1 / (sum((D(i, j) ./ D(:, j)).^b)); % 更新U(i, j)
        end
    end
    
    % 归一化隶属矩阵
    U = U ./ sum(U, 1);
end