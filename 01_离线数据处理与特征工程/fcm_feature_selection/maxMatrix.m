function [value,Index] = maxMatrix(X)
%MAXMATRIX 此处显示有关此函数的摘要
%   此处显示详细说明
    m = size(X,1);
    [M,I] = max(X,[],'all');
    value = M;
    I = find(X==M);
    Index(:,2) = ceil(I/m);
    Index(:,1) = I-(Index(:,2)-1)*m;
end

