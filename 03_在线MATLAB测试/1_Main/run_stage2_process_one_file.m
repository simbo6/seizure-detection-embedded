function [row,ev]=run_stage2_process_one_file(file,output_dir,feature_count,file_index,n_files,app)
%RUN_STAGE2_PROCESS_ONE_FILE 批处理中的单个文件接口。
fprintf('[%d/%d] Fold%d %s/%s/%s\n',file_index,n_files,file.fold, ...
    file.hospital,file.patient,file.name);
ev=empty_event_class_table();
try
    out=run_patient_raw_demo(file.folder,file.name,app.detector.profile, ...
        app.detector.max_feeds,feature_count,app.detector.enable_emg_compensation,app);
    paths=build_output_paths(output_dir,out.hospital_name,out.patient_name,out.file_name, ...
        out.fold,feature_count,app.detector.profile,app);
    out.output_paths=paths;
    % save(char(paths.mat),'out','-v7.3');
    write_points_atomic(out.result_table,char(paths.points));
    % writetable(out.event_table,char(paths.events),'Sheet','events','WriteMode','overwritesheet');
    ev=classify_events(out.true_event_table,out.event_table,out.hospital_name, ...
        out.patient_name,file.name,out.fold);
    row=table(out.hospital_name,out.patient_name,string(out.file_name),out.fold,out.n_feeds, ...
        out.tp,out.tn,out.fp,out.fn,out.accuracy,out.precision,out.recall,out.f1, ...
        out.alarm_points,out.invalid_points,"",'VariableNames', ...
        {'hospital','patient','file','fold','feeds','tp','tn','fp','fn','accuracy', ...
        'precision','recall','f1','alarm_points','invalid_points','error'});
catch ME
    row=table(string(file.hospital),string(file.patient),string(file.name),file.fold, ...
        0,0,0,0,0,NaN,NaN,NaN,NaN,0,0,string(ME.message),'VariableNames', ...
        {'hospital','patient','file','fold','feeds','tp','tn','fp','fn','accuracy', ...
        'precision','recall','f1','alarm_points','invalid_points','error'});
    warning('online_detector:FileFailed','%s',ME.message);
end
end

function write_points_atomic(result_table,target)
[folder,~,ext]=fileparts(target);
temporary=validate_tjx_path([tempname(folder) ext],'write',false);
writetable(result_table,temporary);
[ok,msg]=movefile(temporary,target,'f');
assert(ok,'替换点级结果文件失败：%s',msg);
end

function t=classify_events(true_events,detected_events,hospital,patient,file_name,fold)
% 匹配成功只保留预测事件；未被匹配的真实事件保留为“漏检”。
n_true=height(true_events); n_detected=height(detected_events);
true_start=event_seconds(true_events); true_end=event_seconds(true_events,true);
detected_start=event_seconds(detected_events); detected_end=event_seconds(detected_events,true);
event_class=repmat("误报",n_detected,1); delay_seconds=nan(n_detected,1);
matched_true=false(n_true,1);
for j=1:n_detected
    candidates=find(max(true_start,detected_start(j))<=min(true_end+30,detected_end(j)));
    if ~isempty(candidates)
        [~,q]=min(abs(detected_start(j)-true_start(candidates)));
        matched=candidates(q); event_class(j)="发作";
        delay_seconds(j)=detected_start(j)-true_start(matched);
        matched_true(matched)=true;
    end
end
missed=find(~matched_true); n_missed=numel(missed); n=n_missed+n_detected;
all_class=[repmat("漏检",n_missed,1);event_class];
start_time=[string(true_events{missed,4});string(detected_events{:,4})];
end_time=[string(true_events{missed,5});string(detected_events{:,5})];
duration_seconds=[double(true_events{missed,6});double(detected_events{:,6})];
all_delay=[nan(n_missed,1);delay_seconds];
t=table(repmat(string(hospital),n,1),repmat(string(patient),n,1), ...
    repmat(string(file_name),n,1),repmat(fold,n,1),all_class, ...
    start_time,end_time,duration_seconds,all_delay,'VariableNames', ...
    {'hospital','patient','file','fold','event_class','start_time','end_time', ...
    'duration_seconds','delay_seconds'});
end

function t=empty_event_class_table()
t=table(strings(0,1),strings(0,1),strings(0,1),zeros(0,1), ...
    strings(0,1),strings(0,1),strings(0,1),zeros(0,1),nan(0,1), ...
    'VariableNames',{'hospital','patient','file','fold','event_class', ...
    'start_time','end_time','duration_seconds','delay_seconds'});
end
