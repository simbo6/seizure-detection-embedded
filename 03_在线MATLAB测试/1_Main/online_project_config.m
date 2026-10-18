function app=online_project_config()
%ONLINE_PROJECT_CONFIG 在线癫痫检测项目的统一配置入口。
% 数据路径、模型路径、特征选择、检测参数和输出规则均在此维护。

project_root=fileparts(fileparts(mfilename('fullpath')));
bundle_root=fileparts(project_root);

% 数据与标签。
app.paths.project_root=project_root;
% 交接包不包含患者原始数据；使用前请改为本机数据和标签路径。
app.paths.data_root='PLEASE_CONFIGURE_DATA_ROOT';
app.paths.fold_info_file='PLEASE_CONFIGURE_FOLD_INFO_FILE';
app.paths.true_events_file='PLEASE_CONFIGURE_TRUE_EVENTS_FILE';

% 模型与特征编号。聚类中心和归一化参数使用手动指定的绝对路径；
% feature_indices 非空时直接使用这里给出的固定编号，不再读取特征选择CSV。
app.paths.model_root=fullfile(bundle_root,'04_模型参数');
app.paths.svm_root=app.paths.model_root;
app.paths.fcm_root=fullfile(app.paths.model_root,'fcm');
app.paths.normalization_root=fullfile(app.paths.model_root,'normalization');
app.paths.feature_selection_root=fullfile(app.paths.model_root,'feature_selection');
app.model.svm_dir_template='svm_6_filter';
app.model.feature_selection_file_name='all_k_selected_features.csv';
app.model.fold=1;
app.model.feature_count=25;
app.model.feature_indices=[1,2,3,6,7,8,9,10,14,16,23,24,35,39,42,43, ...
    48,49,51,52,53,54,55,57,58];
app.model.fcm_feature_index=[1 10];
app.model.fcm_exponent=1.2;
app.model.fcm_membership_threshold=0.5;

% 在线检测参数。
app.detector.profile="cv20";
app.detector.max_feeds=inf;
app.detector.enable_emg_compensation=true;
app.detector.save_outputs=true;
app.detector.fs_acc=50;
app.detector.fs_gyr=50;
app.detector.fs_emg=200;
app.detector.feed_seconds=2;
app.detector.analysis_seconds=6;
app.detector.enable_emg_sqi=true;
app.detector.emg_sqi_threshold=0.02;
app.detector.smooth_length=4;
app.detector.history_length=16;
app.detector.nan_window_points=5;
app.detector.interpolate_points=4;
app.detector.alarm_cooldown_seconds=300;
app.detector.profiles.cv20.detect_threshold=0.7;
app.detector.profiles.cv20.detect_points=5;

% 批处理与并行池。parallel_workers为空时由MATLAB自动决定worker数量。
app.processing.enable_parallel=true;
app.processing.parallel_workers=16;
app.processing.files_per_batch=16;

% 输出目录和统一命名规则。
app.paths.output_root=fullfile(project_root,'results');
app.output.stem_format='%s__%s__%s__fold%02d__k%02d__%s';
app.output.mat_suffix='__result.mat';
app.output.points_suffix='__points.csv';
app.output.events_suffix='__events.xlsx';
app.output.summary_suffix='__summary.mat';
app.output.event_checkpoint_every_files=160;
end
