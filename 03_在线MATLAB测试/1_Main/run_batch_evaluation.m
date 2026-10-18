function batch=run_batch_evaluation(feature_count,app)
%RUN_BATCH_EVALUATION 使用统一项目配置执行完整数据集批处理。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'0_Utils'),'-begin'); setup_online_detector_paths(root);
if nargin<2 || isempty(app), app=online_project_config(); end
if nargin<1 || isempty(feature_count), feature_count=app.model.feature_count; end
for i = 1:length(app.model.feature_count)
    feature_count = app.model.feature_count(i);
    batch = run_stage2_feature25_batch(feature_count, app);
end
end
