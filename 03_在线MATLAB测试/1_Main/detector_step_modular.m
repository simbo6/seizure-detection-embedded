function [result,state]=detector_step_modular(state,acc,gyr,emg)
%DETECTOR_STEP_MODULAR 按模块化流程处理一个2秒数据包。
cfg=state.cfg; validate_input(acc,gyr,emg,cfg); state.call_index=state.call_index+1;
state.acc_buffer=update_buffer(state.acc_buffer,acc,cfg.analysis_seconds,cfg.fs_acc);
state.gyr_buffer=update_buffer(state.gyr_buffer,gyr,cfg.analysis_seconds,cfg.fs_gyr);
state.emg_buffer=update_buffer(state.emg_buffer,emg(:),cfg.analysis_seconds,cfg.fs_emg);
result=empty_result(state.call_index,cfg.model.feature_count,numel(cfg.model.feature_indices));
result.model_fold=cfg.model_fold; result.feature_indices=cfg.model.feature_indices;
result.feature_names=cfg.model.feature_names;
if size(state.acc_buffer,1)<cfg.analysis_seconds*cfg.fs_acc
    result.status="warming_up";
    result.message=sprintf('缓存中有%d秒数据，满6秒后开始检测。',state.call_index*2); return
end
[fit,d]=predict_window(state.acc_buffer,state.gyr_buffer,state.emg_buffer,cfg);
[alarm,state,smooth_fit,can_detect]=check_continuous_alarm(state,fit,cfg);
result.fit=fit; result.smooth_fit=smooth_fit; result.seizure=alarm;
result.motion_probability=d.motion_probability; result.motion_detected=d.motion_detected;
result.emg_quality_rm=d.emg_quality_rm; result.svm_score=d.svm_score;
result.features=d.features; result.all_features=d.all_features;
if numel(state.raw_fits)<cfg.history_length
    result.status="postprocess_warming_up";
    result.message=sprintf('已有%d/%d个fit，历史队列满后启动报警判断。',numel(state.raw_fits),cfg.history_length);
elseif alarm==-1 || ~can_detect
    result.status="invalid_signal"; result.message="最近检测窗含无法插值的无效EMG结果。";
elseif alarm==1
    result.status="seizure_alarm"; result.message="连续平滑fit超过阈值，触发报警。";
else
    result.status="normal"; result.message="当前未满足报警条件。";
end
end
function [fit,d]=predict_window(acc,gyr,emg,cfg)
model=cfg.model; d=detail_default(model.feature_count,numel(model.feature_indices));
acc_f=filter_acc_gyr(sqrt(sum(double(acc).^2,2)));
[d.motion_probability,d.motion_detected]=detect_motion(acc_f,model,cfg.motion_threshold,cfg.fs_acc);
if ~d.motion_detected, fit=0; return, end
if any(~isfinite(emg)), fit=NaN; return, end
if isfield(cfg,'apply_emg_compensation') && cfg.apply_emg_compensation
    emg=compensate_emg_system(emg,cfg.fs_emg);
else
    emg=double(emg(:));
end
emg_f=filter_emg(emg); [quality_ok,d.emg_quality_rm]=check_emg_quality(emg_f,cfg);
if ~quality_ok, fit=NaN; return, end
gyr_f=filter_acc_gyr(sqrt(sum(double(gyr).^2,2)));
[d.features,d.all_features]=assemble_feature_vector(acc_f,gyr_f,emg_f,model,cfg);
[fit,d.svm_score]=svm_predict(d.features,model);
end
function validate_input(acc,gyr,emg,cfg)
assert(isequal(size(acc),[cfg.feed_seconds*cfg.fs_acc,3]),'ACC must be 100-by-3.');
assert(isequal(size(gyr),[cfg.feed_seconds*cfg.fs_gyr,3]),'GYR must be 100-by-3.');
assert(numel(emg)==cfg.feed_seconds*cfg.fs_emg,'EMG must contain 400 samples.');
assert(all(isfinite(acc(:)))&&all(isfinite(gyr(:))),'ACC/GYR must be finite.');
end
function d=detail_default(n_all,n_selected)
d=struct('motion_probability',NaN,'motion_detected',false,'emg_quality_rm',NaN, ...
    'svm_score',NaN,'features',nan(1,n_selected),'all_features',nan(1,n_all));
end
function r=empty_result(idx,n_all,n_selected)
r=struct('call_index',idx,'time_seconds',idx*2,'model_fold',NaN,'seizure',0, ...
    'status',"",'message',"",'fit',NaN,'smooth_fit',NaN,'motion_probability',NaN, ...
    'motion_detected',false,'emg_quality_rm',NaN,'svm_score',NaN, ...
    'feature_indices',nan(1,n_selected),'feature_names',strings(1,n_selected), ...
    'features',nan(1,n_selected),'all_features',nan(1,n_all));
end
