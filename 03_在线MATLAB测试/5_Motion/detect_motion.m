function [motion_probability,motion_detected,features]=detect_motion(acc_f,model,threshold,fs)
%DETECT_MOTION 计算指定的ACC聚类特征，并执行FCM运动门控。
if nargin<4 || isempty(fs), fs=50; end
features=extract_imu_features_selected(acc_f,fs,model.fcm_feature_index);
x=(double(features(:)')-double(model.fcm_mean(:)')) ./ double(model.fcm_std(:)');
u=fcm_membership(x,model.fcm_centers,model.fcm_exponent);
motion_probability=u(model.fcm_motion_cluster);
motion_detected=motion_probability>=threshold;
end
