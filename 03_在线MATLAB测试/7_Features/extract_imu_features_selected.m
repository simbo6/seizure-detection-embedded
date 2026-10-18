function y=extract_imu_features_selected(x,fs,idx)
%EXTRACT_IMU_FEATURES_SELECTED 只计算25维 IMU 特征中指定索引的特征。
x=double(x(:)); idx=double(idx(:)'); N=length(x); ma=mean(x);
sx=sort(abs(x)); dx=diff(x); y=zeros(1,numel(idx));
for q=1:numel(idx)
    k=idx(q);
    switch k
        case 1, y(q)=mean(abs(x));
        case 2, y(q)=sqrt(sum(x.^2));
        case 3, y(q)=sqrt(mean((x-ma).^2));
        case 4, y(q)=sx(round(.25*N));
        case 5, y(q)=sx(round(.50*N));
        case 6, y(q)=sx(round(.75*N));
        case 7, y(q)=sx(round(.75*N))-sx(round(.25*N));
        case 8, y(q)=sqrt(sum(dx.^2));
        case 9, y(q)=sum(abs(dx));
        case 10, y(q)=sum((abs(diff(sign(x)))>0)&(abs(dx)>5));
        case 11, y(q)=kurtosis(x);
        case 12, y(q)=skewness(x);
        case 13
            SDSD=sqrt(sum(dx.^2)); SDA=sqrt(abs(sum(x.^2)/N-ma^2));
            y(q)=2*SDA^2-sqrt(SDSD^2/2);
    end
end
if any(idx>=14)
    winN=4*fs; overlapN=2*fs; nfft=2^ceil(log2(winN));
    [pxx,f]=pwelch(x,ones(winN,1),overlapN,nfft,fs);
    lenp=find(f<15,1,'last'); total_power=sum(pxx); band=zeros(1,5);
    for i=1:5
        lo=floor(lenp/5*(i-1))+1; hi=floor(lenp/5*i);
        band(i)=sum(pxx(lo:hi))/total_power;
    end
    [M,I]=sort(pxx(1:lenp),'ascend'); spec=zeros(1,12); spec(1:5)=band;
    spec(6)=f(I(round(lenp*.8))); spec(7)=f(I(round(lenp*.9)));
    spec(8)=f(I(lenp)); spec(9)=M(lenp);
    spec(10)=medfreq(pxx(1:lenp),f(1:lenp));
    spec(11)=meanfreq(pxx(1:lenp),f(1:lenp)); spec(12)=std(pxx(1:lenp));
    for q=1:numel(idx), if idx(q)>=14, y(q)=spec(idx(q)-13); end, end
end
end
