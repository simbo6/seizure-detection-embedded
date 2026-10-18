function y=smooth_latest(x,k)
%SMOOTH_LATEST 计算最近 k 个点中有限数值的均值。
x=x(max(1,end-k+1):end); x=x(~isnan(x));
if isempty(x), y=NaN; else, y=mean(x); end
end
