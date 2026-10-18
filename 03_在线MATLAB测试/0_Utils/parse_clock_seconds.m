function seconds_of_day=parse_clock_seconds(t)
%PARSE_CLOCK_SECONDS 将 HH:mm:ss 字符串解析为当天秒数。
n=numel(t); seconds_of_day=nan(n,1);
for i=1:n
    parts=sscanf(char(t(i)),'%d:%d:%f');
    assert(numel(parts)==3,'Cannot parse time %s; expected HH:mm:ss.',t(i));
    seconds_of_day(i)=parts(1)*3600+parts(2)*60+parts(3);
end
end
