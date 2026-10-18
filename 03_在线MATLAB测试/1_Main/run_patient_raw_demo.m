function out=run_patient_raw_demo(patient_data_dir,file_selector,profile,max_feeds,feature_count,enable_compensation,app)
%RUN_PATIENT_RAW_DEMO 读取一个患者文件并按2秒调用模块化在线检测器。
if nargin<2 || isempty(file_selector), file_selector=1; end
if nargin<7 || isempty(app), app=online_project_config(); end
if nargin<3 || isempty(profile), profile=app.detector.profile; end
if nargin<4 || isempty(max_feeds), max_feeds=app.detector.max_feeds; end
if nargin<5 || isempty(feature_count), feature_count=app.model.feature_count; end
if nargin<6 || isempty(enable_compensation), enable_compensation=app.detector.enable_emg_compensation; end

rec=load_patient_raw_record(patient_data_dir,file_selector,app);
assert(numel(rec.label)>=app.detector.analysis_seconds+1, ...
    '同步有效数据不足以完成对齐后的首个分析窗。');
if logical(enable_compensation), rec.emg=compensate_emg_system(rec.emg,app.detector.fs_emg); end

% 与离线窗口对齐：丢弃第1个有效秒，然后每2秒喂入一次。
rec.acc=rec.acc(app.detector.fs_acc+1:end,:);
rec.gyr=rec.gyr(app.detector.fs_gyr+1:end,:);
rec.emg=rec.emg(app.detector.fs_emg+1:end);
rec.label=rec.label(2:end); rec.source_time=rec.source_time(2:end);
rec.original_seconds=rec.original_seconds(2:end);
cfg=epilepsy_default_config(profile,rec.fold,feature_count,app);
cfg.enable_emg_compensation=logical(enable_compensation);
cfg.apply_emg_compensation=false;
state=init_detector_state(cfg);
acc_feed=cfg.feed_seconds*cfg.fs_acc; gyr_feed=cfg.feed_seconds*cfg.fs_gyr;
emg_feed=cfg.feed_seconds*cfg.fs_emg;
nfeeds=floor(min([size(rec.acc,1)/acc_feed,size(rec.gyr,1)/gyr_feed,numel(rec.emg)/emg_feed]));
nfeeds=min(nfeeds,floor(max_feeds));
assert(nfeeds>=ceil(cfg.analysis_seconds/cfg.feed_seconds),'对齐后有效数据不足一个分析窗。');

results=[];
for i=1:nfeeds
    ia=(i-1)*acc_feed+(1:acc_feed); ig=(i-1)*gyr_feed+(1:gyr_feed);
    ie=(i-1)*emg_feed+(1:emg_feed);
    [r,state]=detector_step_modular(state,rec.acc(ia,:),rec.gyr(ig,:),rec.emg(ie));
    q=i*cfg.feed_seconds; r.true_label=rec.label(q); r.source_time=rec.source_time(q);
    r.original_second_index=rec.original_seconds(q);
    if i==1, results=repmat(r,nfeeds,1); end
    results(i)=r; %#ok<AGROW>
end

result_table=table([results.time_seconds]',string({results.source_time})', ...
    [results.original_second_index]',[results.true_label]',[results.motion_detected]', ...
    [results.motion_probability]',[results.emg_quality_rm]',[results.svm_score]', ...
    [results.fit]',[results.smooth_fit]',[results.seizure]',string({results.status})', ...
    'VariableNames',{'time_seconds','source_time','original_second_index','true_label', ...
    'motion_detected','motion_probability','emg_quality_rm','svm_score','fit', ...
    'smooth_fit','seizure','status'});
true_label=result_table.true_label; seizure=result_table.seizure;
valid=(true_label==-1 | true_label==1) & seizure~=-1; pred=seizure==1;
tp=sum(valid & true_label==1 & pred); tn=sum(valid & true_label==-1 & ~pred);
fp=sum(valid & true_label==-1 & pred); fn=sum(valid & true_label==1 & ~pred);
[~,file_stem]=fileparts(char(rec.file_name));
event_table=build_seizure_events(result_table,seizure==1,rec.hospital_name, ...
    rec.patient_name,file_stem,cfg.alarm_cooldown_seconds);
true_event_table=load_recorded_true_events(rec.hospital_name,rec.patient_name,rec.file_name,app);
out=struct('patient_name',rec.patient_name,'hospital_name',rec.hospital_name, ...
    'fold',rec.fold,'file_path',rec.file_path,'file_name',rec.file_name, ...
    'alignment_offset_seconds',1,'removed_seconds',rec.removed_seconds, ...
    'n_feeds',nfeeds,'cfg',cfg,'results',results,'result_table',result_table, ...
    'event_table',event_table,'true_event_table',true_event_table, ...
    'tp',tp,'tn',tn,'fp',fp,'fn',fn,'alarm_points',sum(seizure==1), ...
    'invalid_points',sum(seizure==-1),'unknown_label_points',sum(~(true_label==-1|true_label==1)));
out.accuracy=(tp+tn)/max(1,tp+tn+fp+fn); out.precision=tp/max(1,tp+fp);
out.recall=tp/max(1,tp+fn);
if out.precision+out.recall==0, out.f1=0;
else, out.f1=2*out.precision*out.recall/(out.precision+out.recall); end
end
