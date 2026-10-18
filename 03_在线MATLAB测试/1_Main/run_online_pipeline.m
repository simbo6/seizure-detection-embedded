function out=run_online_pipeline(patient_data_dir,file_selector,varargin)
%RUN_ONLINE_PIPELINE 读取数据、执行全段补偿、按2秒回放并保存结果。
% 名称-值参数：ProjectConfig、Profile、MaxFeeds、FeatureCount、
% EnableEMGCompensation、OutputDir、SaveOutputs。
root=fileparts(fileparts(mfilename('fullpath')));
addpath(fullfile(root,'0_Utils'),'-begin'); setup_online_detector_paths(root);
app=online_project_config();
p=inputParser;
addRequired(p,'patient_data_dir',@(x)ischar(x)||isstring(x));
addRequired(p,'file_selector');
addParameter(p,'ProjectConfig',app,@isstruct);
addParameter(p,'Profile',""); addParameter(p,'MaxFeeds',[]);
addParameter(p,'FeatureCount',[]); addParameter(p,'EnableEMGCompensation',[]);
addParameter(p,'OutputDir',""); addParameter(p,'SaveOutputs',[]);
parse(p,patient_data_dir,file_selector,varargin{:});
o=p.Results;
app=o.ProjectConfig;
if strlength(string(o.Profile))==0, o.Profile=app.detector.profile; end
if isempty(o.MaxFeeds), o.MaxFeeds=app.detector.max_feeds; end
if isempty(o.FeatureCount), o.FeatureCount=app.model.feature_count; end
if isempty(o.EnableEMGCompensation), o.EnableEMGCompensation=app.detector.enable_emg_compensation; end
if isempty(o.SaveOutputs), o.SaveOutputs=app.detector.save_outputs; end
if strlength(string(o.OutputDir))==0, o.OutputDir=app.paths.output_root; end
patient_data_dir=validate_tjx_path(patient_data_dir,'read',true);
out=run_patient_raw_demo(patient_data_dir,file_selector,o.Profile,o.MaxFeeds, ...
    o.FeatureCount,logical(o.EnableEMGCompensation),app);
if ~logical(o.SaveOutputs), return, end
o.OutputDir=validate_tjx_path(o.OutputDir,'write',isfolder(o.OutputDir));
if ~isfolder(o.OutputDir), mkdir(o.OutputDir); end
p=build_output_paths(o.OutputDir,out.hospital_name,out.patient_name,out.file_name, ...
    out.fold,o.FeatureCount,o.Profile,app);
out.output_paths=p;
save(char(p.mat),'out','-v7.3');
writetable(out.result_table,char(p.points));
writetable(out.event_table,char(p.events), ...
    'Sheet','events','WriteMode','overwritesheet');
end
