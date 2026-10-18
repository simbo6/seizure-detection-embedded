function [quality_ok,rm]=check_emg_quality(emg_f,cfg)
%CHECK_EMG_QUALITY 将各秒均值的极差与配置中的 SQI 阈值比较。
x=double(emg_f(:)); n=cfg.fs_emg;
assert(mod(numel(x),n)==0,'EMG window length must be a whole number of seconds.');
means=mean(reshape(x,n,[]),1); rm=max(means)-min(means);
quality_ok=~cfg.enable_emg_sqi || rm<=cfg.emg_sqi_threshold;
end
