function [pred,d,C] = recluster(pred,C,d)
%UNTITLED2 此处显示有关此函数的摘要
%   此处显示详细说明
    Cn = size(C,1);
    if nargin<3
        d = nan(Cn,1);
        for j = 1:Cn
            d(j) = norm(C(j,:));
        end
        [~,d] = sort(d,'ascend');
    end
    C = C(d,:);
    if isempty(pred), return;end
    for j = 1:Cn
        pred(pred==d(j)) = -j;
    end
    pred = -pred;
end

