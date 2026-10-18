function rec=load_patient_raw_record(patient_data_dir,file_selector,app)
%LOAD_PATIENT_RAW_RECORD 明确的患者原始MAT数据读取接口。
% 输入目录必须是“医院/患者/data”；输出统一为 double 数组和元数据结构。
if nargin<2 || isempty(file_selector), file_selector=1; end
if nargin<3 || isempty(app), app=online_project_config(); end
patient_data_dir=validate_tjx_path(patient_data_dir,'read',true);
assert(isfolder(patient_data_dir),'患者数据路径不是目录：%s',patient_data_dir);
[patient_dir,data_leaf]=fileparts(patient_data_dir);
assert(strcmpi(data_leaf,'data'),'患者数据路径末级必须是 data：%s',patient_data_dir);
[hospital_dir,patient_name]=fileparts(patient_dir);
[~,hospital_name]=fileparts(hospital_dir);

files=dir(fullfile(patient_data_dir,'*.mat')); files=files(~[files.isdir]);
assert(~isempty(files),'患者data目录中没有MAT文件：%s',patient_data_dir);
[~,order]=sort({files.name}); files=files(order);
if isnumeric(file_selector)
    validateattributes(file_selector,{'numeric'},{'scalar','integer','>=',1,'<=',numel(files)});
    file=files(file_selector);
else
    hit=find(string({files.name})==string(file_selector),1);
    assert(~isempty(hit),'患者data目录中找不到文件：%s',string(file_selector));
    file=files(hit);
end
file_path=validate_tjx_path(fullfile(file.folder,file.name),'read',true);
s=load(file_path);
assert(isfield(s,'data')&&iscell(s.data)&&numel(s.data)>=5, ...
    '原始MAT必须含有data cell，且data{2}=ACC、data{3}=GYR、data{5}=EMG。');
assert(isfield(s,'label'),'原始MAT缺少每秒label。');

acc=double(s.data{2}); gyr=double(s.data{3});
if isfield(s,'emg_removed_s'), emg=double(s.emg_removed_s(:));
else, emg=double(s.data{5}(:)); end
label=double(s.label(:));
if isstring(s.data{1}) || iscellstr(s.data{1})
    source_time=string(s.data{1}(:));
else
    source_time=string((1:numel(label))');
end
[acc,gyr,emg,label,source_time,original_seconds,removed_seconds]= ...
    remove_invalid_seconds(acc,gyr,emg,label,source_time,app.detector.fs_acc, ...
    app.detector.fs_gyr,app.detector.fs_emg);

fold_file=validate_tjx_path(app.paths.fold_info_file,'read',true);
info=load(fold_file,'S31'); assert(isfield(info,'S31'),'折分组文件缺少S31变量。');
S=strtrim(string(info.S31)); p=strtrim(string(patient_name)); h=strtrim(string(hospital_name));
ix=find(S(:,1)==p & S(:,2)==h,1); if isempty(ix), ix=find(S(:,1)==p,1); end
assert(~isempty(ix),'S31中找不到患者：%s / %s',hospital_name,patient_name);
fold=str2double(S(ix,3)); assert(ismember(fold,1:5),'患者折号无效。');

rec=struct('acc',acc,'gyr',gyr,'emg',emg,'label',label, ...
    'source_time',source_time,'original_seconds',original_seconds, ...
    'removed_seconds',removed_seconds,'fold',fold, ...
    'hospital_name',string(hospital_name),'patient_name',string(patient_name), ...
    'file_name',string(file.name),'file_path',string(file_path));
end

function [acc2,gyr2,emg2,label2,time2,original_seconds,n_removed]= ...
    remove_invalid_seconds(acc,gyr,emg,label,time_series,fs_acc,fs_gyr,fs_emg)
nsec=floor(min([size(acc,1)/fs_acc,size(gyr,1)/fs_gyr,numel(emg)/fs_emg, ...
    numel(label),numel(time_series)]));
valid=false(nsec,1);
for i=1:nsec
    ia=(i-1)*fs_acc+(1:fs_acc); ig=(i-1)*fs_gyr+(1:fs_gyr);
    ie=(i-1)*fs_emg+(1:fs_emg);
    valid(i)=all(isfinite(acc(ia,:)),'all') && all(isfinite(gyr(ig,:)),'all') && ...
        all(isfinite(emg(ie))) && isfinite(label(i));
end
original_seconds=find(valid); n_removed=sum(~valid);
acc2=zeros(numel(original_seconds)*fs_acc,3);
gyr2=zeros(numel(original_seconds)*fs_gyr,3);
emg2=zeros(numel(original_seconds)*fs_emg,1);
for j=1:numel(original_seconds)
    i=original_seconds(j);
    ia=(i-1)*fs_acc+(1:fs_acc); ig=(i-1)*fs_gyr+(1:fs_gyr);
    ie=(i-1)*fs_emg+(1:fs_emg);
    oa=(j-1)*fs_acc+(1:fs_acc); og=(j-1)*fs_gyr+(1:fs_gyr);
    oe=(j-1)*fs_emg+(1:fs_emg);
    acc2(oa,:)=acc(ia,:); gyr2(og,:)=gyr(ig,:); emg2(oe)=emg(ie);
end
label2=label(valid); time2=time_series(valid);
end
