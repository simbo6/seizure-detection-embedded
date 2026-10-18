function t=load_recorded_true_events(hospital,patient,file_name,app)
%LOAD_RECORDED_TRUE_EVENTS 从统一配置指定的工作簿读取人工记录事件。
if nargin<4 || isempty(app), app=online_project_config(); end
file=validate_tjx_path(app.paths.true_events_file,'read',true);
gt=readtable(file,'Sheet','Sheet1','VariableNamingRule','preserve');
if isempty(gt), t=empty_table(); return, end
[~,stem]=fileparts(char(file_name));
H=strtrim(string(gt{:,1})); P=strtrim(string(gt{:,2})); F=strtrim(string(gt{:,3}));
ix=H==strtrim(string(hospital)) & P==strtrim(string(patient)) & ...
    F==strtrim(string(stem));
g=gt(ix,:); if isempty(g), t=empty_table(); return, end
t=table(string(g{:,1}),string(g{:,2}),string(g{:,3}),string(g{:,4}), ...
    string(g{:,5}),double(g{:,6}),'VariableNames', ...
    {'医院','患者名','文件名','发作开始时间','发作结束时间','总时长_秒'});
end
function t=empty_table()
t=table(strings(0,1),strings(0,1),strings(0,1),strings(0,1),strings(0,1),zeros(0,1), ...
    'VariableNames',{'医院','患者名','文件名','发作开始时间','发作结束时间','总时长_秒'});
end
