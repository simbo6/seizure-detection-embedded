function [alarm,state,smooth_fit,can_detect]=check_continuous_alarm(state,fit,cfg)
%CHECK_CONTINUOUS_ALARM 更新 fit 历史队列并执行连续超阈值判定。
if ~isfield(state,'alarm_cooldown_seconds'), state.alarm_cooldown_seconds=0; end
state.alarm_cooldown_seconds=max(0,state.alarm_cooldown_seconds-cfg.feed_seconds);
state.raw_fits(end+1)=fit;
if numel(state.raw_fits)>cfg.history_length, state.raw_fits=state.raw_fits(end-cfg.history_length+1:end); end
% 只有最近5个原始点含NaN时，才扫描整个历史窗口并执行插值。
work_fits=state.raw_fits; can_detect=true;
if numel(work_fits)>=cfg.history_length && any(isnan(work_fits(end-cfg.nan_window_points+1:end)))
    [work_fits,can_detect]=interpolate_recent_nans(work_fits,cfg);
end
% 保留历史平滑值；插值点采用当前位置及前面最多2点的均值。
smooth_history=[state.smooth_fits,NaN];
if numel(smooth_history)>numel(work_fits), smooth_history=smooth_history(end-numel(work_fits)+1:end); end
if numel(smooth_history)<numel(work_fits), smooth_history=[nan(1,numel(work_fits)-numel(smooth_history)),smooth_history]; end
for j=1:numel(work_fits)
    if isnan(state.raw_fits(j)) && ~isnan(work_fits(j))
        local=work_fits(max(1,j-2):j); local=local(~isnan(local));
        if ~isempty(local), smooth_history(j)=mean(local); end
    end
end
% 最新点正常时使用最近4点均值；最新点为NaN时保留NaN，不能被平滑掉。
if ~isnan(work_fits(end))
    smooth_fit=smooth_latest(work_fits,cfg.smooth_length);
    smooth_history(end)=smooth_fit;
else
    smooth_fit=NaN; smooth_history(end)=NaN;
end
state.smooth_fits=smooth_history;
if numel(state.raw_fits)<cfg.history_length
    alarm=0; return
end
nan_points=min(numel(state.raw_fits),cfg.nan_window_points);
recent_work=work_fits(end-nan_points+1:end);
if ~can_detect || any(isnan(recent_work)) || isnan(smooth_fit)
    alarm=-1;
elseif numel(state.smooth_fits)>=cfg.detect_points && all(state.smooth_fits(end-cfg.detect_points+1:end)>cfg.detect_threshold)
    if state.alarm_cooldown_seconds>0
        alarm=0;
    else
        alarm=1;
        state.alarm_cooldown_seconds=cfg.alarm_cooldown_seconds;
    end
else
    alarm=0;
end
end
