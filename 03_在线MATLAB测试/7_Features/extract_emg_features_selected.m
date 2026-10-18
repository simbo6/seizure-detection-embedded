function y=extract_emg_features_selected(x,fs,idx)
%EXTRACT_EMG_FEATURES_SELECTED 只计算21维 EMG 特征中指定索引的特征。
x=double(x(:)); idx=double(idx(:)'); ax=abs(x); N=numel(x); y=zeros(1,numel(idx));
for q=1:numel(idx)
    k=idx(q);
    switch k
        case 1, y(q)=sum(ax)/N;
        case 2, y(q)=sqrt(sum(x.^2));
        case 3, y(q)=sqrt(mean((x-mean(x)).^2));
        case 4, y(q)=sum(x.^2);
        case 5, y(q)=sum(abs(diff(x)));
        case 6, y(q)=cross_zeros_local(x,50);
        case 7, y(q)=sum(ax<.4);
        case 8, y(q)=sum(ax>=.4 & ax<.8);
        case 9, y(q)=sum(ax>=.8 & ax<1.2);
        case 10, y(q)=sum(ax>=1.2 & ax<1.6);
        case 11, y(q)=sum(ax>=1.6 & ax<=90);
    end
end
if any(idx>=12)
    winN=4*fs; overlapN=2*fs; nfft=2^ceil(log2(winN));
    [Pxx,f]=pwelch(x,ones(winN,1),overlapN,nfft,fs);
    lenp=length(Pxx)-1; den=sum(Pxx(1:lenp)); spec=zeros(1,10);
    for i=1:4, spec(i)=sum(Pxx(floor(lenp/4*(i-1))+1:floor(lenp/4*i)))/den; end
    spec(5)=medfreq(Pxx,linspace(0,fs/2,lenp+1)); spec(6)=meanfreq(Pxx,f);
    [M,I]=sort(Pxx(1:lenp),'ascend'); spec(7)=f(I(round(lenp*.8)));
    spec(8)=f(I(round(lenp*.9))); spec(9)=f(I(lenp)); spec(10)=M(lenp);
    for q=1:numel(idx), if idx(q)>=12, y(q)=spec(idx(q)-11); end, end
end
end
function count=cross_zeros_local(x,thr)
i=find(abs(x)>thr,1); count=0; if isempty(i), return, end
positive=x(i)>0; N=length(x);
while i<=N
    if positive, next=find(x(i+1:end)<-thr,1)+i;
    else, next=find(x(i+1:end)>thr,1)+i; end
    if isempty(next), break, end
    count=count+1; i=next; positive=~positive;
end
end
