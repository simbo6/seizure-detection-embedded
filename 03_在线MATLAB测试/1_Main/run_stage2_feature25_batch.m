function batch=run_stage2_feature25_batch(feature_count,app)
%RUN_STAGE2_FEATURE25_BATCH 按S31清单顺序处理统一数据根目录中的全部文件。
if nargin<2 || isempty(app), app=online_project_config(); end
if nargin<1 || isempty(feature_count), feature_count=app.model.feature_count; end
data_root=validate_tjx_path(app.paths.data_root,'read',true);
info_file=validate_tjx_path(app.paths.fold_info_file,'read',true);
output_root=validate_tjx_path(app.paths.output_root,'write',isfolder(app.paths.output_root));
if ~isfolder(output_root), mkdir(output_root); end
output_dir=fullfile(output_root,sprintf('batch_6filter_k%02d',feature_count));
output_dir=validate_tjx_path(output_dir,'write',isfolder(output_dir));
if ~isfolder(output_dir), mkdir(output_dir); end
info=load(info_file,'S31'); S=strtrim(string(info.S31));
files=struct('folder',{},'name',{},'fold',{},'hospital',{},'patient',{});
for i=1:size(S,1)
    folder=validate_tjx_path(fullfile(data_root,S(i,2),S(i,1),'data'),'read',true);
    ff=dir(fullfile(folder,'*.mat')); ff=ff(~[ff.isdir]);
    for j=1:numel(ff)
        files(end+1)=struct('folder',ff(j).folder,'name',ff(j).name, ...
            'fold',str2double(S(i,3)),'hospital',S(i,2),'patient',S(i,1)); %#ok<AGROW>
    end
end
rows=cell(numel(files),1);
all_events=empty_event_class_table();
event_mat_file=validate_tjx_path(fullfile(output_dir,'all_events.mat'),'write',false);
event_xlsx_file=validate_tjx_path(fullfile(output_dir, ...
    sprintf('all_events_%d.xlsx',feature_count)),'write',false);
checkpoint_every=max(1,round(app.output.event_checkpoint_every_files));
files_per_batch=max(1,round(app.processing.files_per_batch));
[use_parallel,pool]=open_project_parallel_pool(app);
if use_parallel
    files_per_batch=pool.NumWorkers;
    fprintf('并行池已启用：%d workers；每批最多处理%d个文件。\n', ...
        pool.NumWorkers,files_per_batch);
else
    fprintf('使用串行批处理；每批最多处理%d个文件。\n',files_per_batch);
end
last_checkpoint=0;
for first=1:files_per_batch:numel(files)
    indices=first:min(first+files_per_batch-1,numel(files));
    chunk_files=files(indices); n_chunk=numel(indices);
    chunk_rows=cell(n_chunk,1); chunk_events=cell(n_chunk,1);
    if use_parallel
        parfor j=1:n_chunk
            i=indices(j);
            [chunk_rows{j},chunk_events{j}]=run_stage2_process_one_file( ...
                chunk_files(j),output_dir,feature_count,i,numel(files),app);
        end
    else
        for j=1:n_chunk
            i=indices(j);
            [chunk_rows{j},chunk_events{j}]=run_stage2_process_one_file( ...
                chunk_files(j),output_dir,feature_count,i,numel(files),app);
        end
    end
    for j=1:n_chunk
        i=indices(j); rows{i}=chunk_rows{j};
        if height(chunk_events{j})>0
            all_events=[all_events;chunk_events{j}]; %#ok<AGROW>
        end
    end
    completed=indices(end);
    if completed-last_checkpoint>=checkpoint_every || completed==numel(files)
        save_event_checkpoint(all_events,event_mat_file,event_xlsx_file);
        fprintf('总体事件检查点已保存：%d/%d 个文件。\n',completed,numel(files));
        last_checkpoint=completed;
    end
end
if isempty(rows), summary=table(); else, summary=vertcat(rows{:}); end
summary_file=validate_tjx_path(fullfile(output_dir, ...
    sprintf('batch__k%02d__summary.xlsx',feature_count)),'write',false);
writetable(summary,summary_file,'Sheet','files','WriteMode','overwritesheet');
batch=struct('feature_count',feature_count,'data_root',string(data_root), ...
    'output_dir',string(output_dir),'n_files',numel(files),'summary',summary, ...
    'all_events',all_events,'all_events_mat',string(event_mat_file), ...
    'all_events_xlsx',string(event_xlsx_file));
batch_file=validate_tjx_path(fullfile(output_dir, ...
    sprintf('batch__k%02d__result.mat',feature_count)),'write',false);
save(batch_file,'batch','-v7.3');
end

function [enabled,pool]=open_project_parallel_pool(app)
enabled=logical(app.processing.enable_parallel); pool=[];
if ~enabled, return, end
try
    cluster=parcluster('local'); max_workers=cluster.NumWorkers;
    workers=app.processing.parallel_workers;
    if isempty(workers), workers=max_workers; end
    validateattributes(workers,{'numeric'},{'scalar','integer','positive'});
    workers=min(workers,max_workers);
    pool=gcp('nocreate');
    if ~isempty(pool) && pool.NumWorkers~=workers
        delete(pool); pool=[];
    end
    if isempty(pool)
        pool=parpool(cluster,workers);
    end
catch ME
    warning('online_detector:ParallelUnavailable', ...
        '并行池启动失败，将退回串行处理：%s',ME.message);
    enabled=false; pool=[];
end
end

function save_event_checkpoint(all_events,mat_file,xlsx_file)
% 先完整写入临时文件，再替换正式文件，避免留下半写入检查点。
[folder,~,~]=fileparts(char(mat_file));
mat_tmp=validate_tjx_path([tempname(folder) '.mat'],'write',false);
xlsx_tmp=validate_tjx_path([tempname(folder) '.xlsx'],'write',false);
save(mat_tmp,'all_events','-v7.3');
writetable(all_events,xlsx_tmp,'Sheet','events','WriteMode','overwritesheet');
[ok,msg]=movefile(mat_tmp,char(mat_file),'f');
assert(ok,'替换总体事件MAT检查点失败：%s',msg);
[ok,msg]=movefile(xlsx_tmp,char(xlsx_file),'f');
assert(ok,'替换总体事件Excel检查点失败：%s',msg);
end

function t=empty_event_class_table()
t=table(strings(0,1),strings(0,1),strings(0,1),zeros(0,1), ...
    strings(0,1),strings(0,1),strings(0,1),zeros(0,1),nan(0,1), ...
    'VariableNames',{'hospital','patient','file','fold','event_class', ...
    'start_time','end_time','duration_seconds','delay_seconds'});
end
