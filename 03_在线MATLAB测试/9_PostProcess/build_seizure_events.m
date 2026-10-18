function event_table=build_seizure_events(result_table,event_mask,hospital_name,patient_name,file_name,merge_gap_seconds)
%BUILD_SEIZURE_EVENTS 合并间隔不超过300秒的连续报警点事件。
if nargin<6 || isempty(merge_gap_seconds), merge_gap_seconds=300; end
assert(height(result_table)==numel(event_mask)); event_mask=logical(event_mask(:));
source_time=string(result_table.source_time);
clock_seconds=unwrap_midnight(parse_clock_seconds(source_time));
edge=diff([false;event_mask;false]); starts=find(edge==1); ends=find(edge==-1)-1;
if ~isempty(starts)
    ms=starts(1); me=ends(1);
    for i=2:numel(starts)
        % 以当前事件的首次报警点为基准，避免“每段间隔都小于300秒”而链式合并成超长事件。
        if clock_seconds(starts(i))-clock_seconds(ms(end))<merge_gap_seconds
            me(end)=ends(i);
        else
            ms(end+1,1)=starts(i); me(end+1,1)=ends(i); %#ok<AGROW>
        end
    end
    starts=ms(:); ends=me(:);
end
n=numel(starts); hospital=repmat(string(hospital_name),n,1);
patient=repmat(string(patient_name),n,1); source_file=repmat(string(file_name),n,1);
start_time=strings(n,1); end_time=strings(n,1); duration_seconds=zeros(n,1);
for i=1:n
    start_time(i)=source_time(starts(i)); end_time(i)=source_time(ends(i));
    duration_seconds(i)=round(clock_seconds(ends(i))-clock_seconds(starts(i)))+1;
end
event_table=table(hospital,patient,source_file,start_time,end_time,duration_seconds, ...
    'VariableNames',{'医院','患者名','文件名','发作开始时间','发作结束时间','总时长_秒'});
end
