function x=event_seconds(t,is_end)
%EVENT_SECONDS 将事件表中的开始或结束时刻字符串转换为秒数。
if nargin<2, is_end=false; end
if height(t)==0, x=zeros(0,1); return, end
col=4+is_end; x=parse_clock_seconds(string(t{:,col})); x=unwrap_midnight(x);
end
