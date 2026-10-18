function [fit,score]=svm_predict(features,model)
%SVM_PREDICT 依次执行 Z-score 标准化、LinearSVC 决策和 Sigmoid 概率变换。
z=(double(features)-model.feature_mean)./model.feature_std;
score=z*model.svm_w+model.svm_bias;
fit=1/(1+exp(-score));
end
