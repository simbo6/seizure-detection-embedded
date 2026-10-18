function buffer = update_buffer(buffer,new_data,analysis_seconds,fs)
%UPDATE_BUFFER 追加一个数据包，并只保留最近一个分析窗口的数据。
new_data=double(new_data);
buffer=[buffer;new_data];
n=analysis_seconds*fs;
if size(buffer,1)>n, buffer=buffer(end-n+1:end,:); end
end
