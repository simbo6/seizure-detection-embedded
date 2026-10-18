function [x,ok]=interpolate_recent_nans(x,cfg)
%INTERPOLATE_RECENT_NANS 只填补长度受限且两端有效的内部 NaN 连续段。
ok=true; n=numel(x); i=1;
while i<=n
    if ~isnan(x(i)), i=i+1; continue, end
    j=i; while j<n && isnan(x(j+1)), j=j+1; end
    len=j-i+1;
    if i>1 && j<n && len<=cfg.interpolate_points
        x(i:j)=interp1([i-1,j+1],x([i-1,j+1]),i:j);
    elseif j>=n-cfg.nan_window_points+1
        ok=false;
    end
    i=j+1;
end
end
