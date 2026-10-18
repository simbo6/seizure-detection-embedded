function t=unwrap_midnight(t)
%UNWRAP_MIDNIGHT 跨越午夜时展开时钟秒数，使时间保持单调递增。
day_offset=0;
for i=2:numel(t)
    if t(i)+day_offset<t(i-1)-12*3600, day_offset=day_offset+24*3600; end
    t(i)=t(i)+day_offset;
end
end
