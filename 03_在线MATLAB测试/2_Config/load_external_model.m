function model=load_external_model(fold,feature_count,app)
%LOAD_EXTERNAL_MODEL 现有模型加载器的兼容名称。
if nargin<3 || isempty(app), app=online_project_config(); end
model=epilepsy_external_model(fold,feature_count,app);
end
