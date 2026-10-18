function [features,all_features]=assemble_feature_vector(acc_f,gyr_f,emg_f,model,cfg)
%ASSEMBLE_FEATURE_VECTOR 构造稀疏的71维特征存储，并裁剪出选中特征。
sel=model.feature_indices(:)';
acc_need=sel(sel<=25); gyr_need=sel(sel>25 & sel<=50)-25; emg_need=sel(sel>50)-50;
acc_features=nan(1,25); gyr_features=nan(1,25); emg_features=nan(1,21);
acc_features(acc_need)=extract_imu_features_selected(acc_f,cfg.fs_acc,acc_need);
gyr_features(gyr_need)=extract_imu_features_selected(gyr_f,cfg.fs_gyr,gyr_need);
emg_features(emg_need)=extract_emg_features_selected(emg_f,cfg.fs_emg,emg_need);
all_features=[acc_features,gyr_features,emg_features]; features=all_features(sel);
end
