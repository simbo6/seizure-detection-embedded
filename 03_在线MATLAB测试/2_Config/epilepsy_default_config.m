function cfg=epilepsy_default_config(profile,fold,feature_count,app)
%EPILEPSY_DEFAULT_CONFIG 生成模块化检测器配置。
if nargin<1 || isempty(profile), profile="cv20"; end
if nargin<2 || isempty(fold), fold=1; end
if nargin<3 || isempty(feature_count), feature_count=25; end
if nargin<4 || isempty(app), app=online_project_config(); end
model=load_external_model(fold,feature_count,app);
cfg.fs_acc=app.detector.fs_acc; cfg.fs_gyr=app.detector.fs_gyr; cfg.fs_emg=app.detector.fs_emg;
cfg.feed_seconds=app.detector.feed_seconds; cfg.analysis_seconds=app.detector.analysis_seconds;
cfg.model_fold=fold; cfg.model=model;
cfg.enable_emg_compensation=app.detector.enable_emg_compensation;
cfg.apply_emg_compensation=true; % 旧接口兼容字段，仅用于单窗口补偿模式
cfg.enable_emg_sqi=app.detector.enable_emg_sqi;
cfg.emg_sqi_threshold=app.detector.emg_sqi_threshold;
cfg.motion_threshold=model.fcm_membership_threshold;
cfg.smooth_length=app.detector.smooth_length;
cfg.history_length=app.detector.history_length;
% NaN质量检查覆盖最近5个窗口，内部连续NaN最多允许插值4个点。
cfg.nan_window_points=app.detector.nan_window_points;
cfg.interpolate_points=app.detector.interpolate_points;
cfg.alarm_cooldown_seconds=app.detector.alarm_cooldown_seconds;
switch lower(string(profile))
    case {"cv20","v4_july"}
        cfg.profile="cv20";
        cfg.detect_threshold=app.detector.profiles.cv20.detect_threshold;
        cfg.detect_points=app.detector.profiles.cv20.detect_points;
    case {"cv20_strict","s2_robust"}
        cfg.profile="cv20_strict";
        cfg.detect_threshold=app.detector.profiles.cv20_strict.detect_threshold;
        cfg.detect_points=app.detector.profiles.cv20_strict.detect_points;
    otherwise
        error('Unknown profile: %s.',profile);
end
assert(numel(model.svm_w)==numel(model.feature_indices));
assert(all(model.feature_std>0));
assert(cfg.history_length>=cfg.smooth_length+cfg.interpolate_points);
end
