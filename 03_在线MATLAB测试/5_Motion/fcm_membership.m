function u=fcm_membership(x,centers,m)
%FCM_MEMBERSHIP 计算向量 x 对各FCM聚类中心的隶属度。
x=double(x(:)'); centers=double(centers);
if isvector(centers)
    if numel(centers)==numel(x), centers=reshape(centers,1,[]);
    else, centers=centers(:); end
elseif size(centers,2)~=numel(x) && size(centers,1)==numel(x)
    centers=centers.';
end
assert(size(centers,2)==numel(x), ...
    'FCM特征维度(%d)与聚类中心维度(%d)不一致。',numel(x),size(centers,2));
d=sqrt(sum((centers-x).^2,2));
if any(d==0), u=zeros(size(d)); u(find(d==0,1))=1; return, end
p=2/(m-1); u=1./sum((d./d').^p,2); u=u/sum(u);
end
