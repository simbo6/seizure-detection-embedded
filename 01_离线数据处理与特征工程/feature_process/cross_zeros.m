function count = cross_zeros(emg,thr)
% 返回 emg 的零交叉点数

    i = find(abs(emg) > thr,1);
    count = 0;
    if isempty(i)
        return
    else
        N = length(emg);
        sign = emg(i)>0;
        while i <= N
            if sign       
                row = find(emg(i+1:end) < -thr,1) + i;
            else
                row = find(emg(i+1:end) > thr,1) + i;
            end
            if ~isempty(row)
                count = count + 1;
                i = row;
                sign = ~sign;
            else
                break
            end
        end
    end
end

