function state=init_detector_state(cfg)
%INIT_DETECTOR_STATE 初始化数据缓存和后处理历史队列。
state.cfg=cfg; state.acc_buffer=zeros(0,3); state.gyr_buffer=zeros(0,3);
state.emg_buffer=zeros(0,1); state.raw_fits=zeros(1,0);
state.smooth_fits=zeros(1,0); state.call_index=0;
% 报警冷却计时：一次报警后，300秒内不重复报警。
state.alarm_cooldown_seconds=0;
end
