function eva = evaSample(y,pred,P,N)
% 根据标签计算 SR
% P: 正样本标签
% N: 负样本标签
% 输入（Y,Ypre,Plable,Nlabel)
% 输出 SR（TPs,FNs,FPs,TNs,ACC,SEL,SENS,SPEC,F2)
    TP = length(find(pred == P & y == P));
    FP = length(find(pred == P & y == N));
    TN = length(find(pred == N & y == N));
    FN = length(find(pred == N & y == P));
    SEL = TP/(TP+FP); %选择性
    SENS = TP/(TP+FN); %灵敏性
    SPEC = TN/(TN+FP); %特异性
    ACC = (TP+TN)/(TP+ FP+TN+FN);
    beta = 2;
    F2 = ((1+beta*beta)*TP)/((1+beta*beta)*TP+beta*beta*FN+FP);
    beta = 1;
    F1 = ((1+beta*beta)*TP)/((1+beta*beta)*TP+beta*beta*FN+FP);
    eva = [TP,FN,FP,TN,ACC,SEL,SENS,SPEC,F2,F1];
end

