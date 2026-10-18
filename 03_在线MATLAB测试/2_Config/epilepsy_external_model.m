function model=epilepsy_external_model(fold,k,app)
%EPILEPSY_EXTERNAL_MODEL 从统一配置指定的位置加载某一折的完整模型。
if nargin<3 || isempty(app), app=online_project_config(); end
validateattributes(fold,{'numeric'},{'scalar','integer','>=',1,'<=',5});
validateattributes(k,{'numeric'},{'scalar','integer','positive'});

svm_root=validate_tjx_path(app.paths.svm_root,'read',true);
if isempty(app.model.feature_indices)
    feature_file=fullfile(app.paths.feature_selection_root,sprintf('%dcross',fold), ...
        app.model.feature_selection_file_name);
    feature_file=validate_tjx_path(feature_file,'read',true);
    feature_indices=read_selected(feature_file,k);
else
    feature_indices=double(app.model.feature_indices(:)');
    assert(numel(feature_indices)==k, ...
        '统一配置中的 feature_indices 数量必须等于 feature_count=%d。',k);
end
assert(all(isfinite(feature_indices)) && all(feature_indices==fix(feature_indices)) && ...
    all(feature_indices>=1 & feature_indices<=71),'特征编号必须是1到71之间的整数。');

normalization_root=validate_tjx_path(app.paths.normalization_root,'read',true);
fcm_root=validate_tjx_path(app.paths.fcm_root,'read',true);
norm_file=validate_tjx_path(fullfile(normalization_root, ...
    sprintf('norm_params_fold%d.mat',fold)),'read',true);
center_file=validate_tjx_path(fullfile(fcm_root,sprintf('%dcross',fold), ...
    'center.mat'),'read',true);
fcm_norm_file=validate_tjx_path(fullfile(fcm_root,sprintf('%dcross',fold), ...
    'fcm_params.mat'),'read',true);
svm_dir=validate_tjx_path(fullfile(svm_root,sprintf(app.model.svm_dir_template,k)), ...
    'read',true);
fold_dir=validate_tjx_path(fullfile(svm_dir,sprintf('fold_%d',fold)),'read',true);
w_file=validate_tjx_path(fullfile(fold_dir,'w.npy'),'read',true);
b_file=validate_tjx_path(fullfile(fold_dir,'b.npy'),'read',true);

n=load(norm_file,'feature_mean','feature_std');
c=load(center_file,'center');
fc=load(fcm_norm_file,'fcm_mean','fcm_std');
fcm_idx=double(app.model.fcm_feature_index(:)');
fcm_mean=select_fcm_values(fc.fcm_mean,fcm_idx,'fcm_mean');
fcm_std=select_fcm_values(fc.fcm_std,fcm_idx,'fcm_std');
fcm_centers=double(c.center);
if size(fcm_centers,2)~=numel(fcm_idx) && size(fcm_centers,1)==numel(fcm_idx)
    fcm_centers=fcm_centers.';
end
assert(size(fcm_centers,2)==numel(fcm_idx),'FCM中心矩阵与聚类特征数量不一致。');
model=struct('fold',fold,'feature_count',71,'feature_indices',feature_indices, ...
    'feature_mean',n.feature_mean(feature_indices),'feature_std',n.feature_std(feature_indices), ...
    'fcm_centers',fcm_centers,'fcm_mean',fcm_mean,'fcm_std',fcm_std, ...
    'fcm_feature_index',app.model.fcm_feature_index, ...
    'fcm_exponent',app.model.fcm_exponent, ...
    'fcm_membership_threshold',app.model.fcm_membership_threshold);
model.svm_w=read_npy_double(w_file); model.svm_w=model.svm_w(:);
b=read_npy_double(b_file); model.svm_bias=b(1);
model.all_feature_names=all_feature_names();
model.feature_names=model.all_feature_names(feature_indices);
[~,model.fcm_motion_cluster]=max(sqrt(sum(model.fcm_centers.^2,2)));
assert(numel(model.svm_w)==k,'SVM权重数量与特征数量不一致。');
assert(all(model.feature_std>0),'特征标准差必须全部大于0。');
end

function y=select_fcm_values(values,idx,label)
values=double(values(:)');
if numel(values)==numel(idx), y=values;
elseif numel(values)>=max(idx), y=values(idx);
else, error('FCM %s 长度不足，无法读取特征编号[%s]。',label,num2str(idx));
end
end

function idx=read_selected(file,k)
t=readtable(file,'VariableNamingRule','preserve');
row=t(t{:,1}==k,:);
assert(height(row)==1,'特征选择文件中不存在唯一的 k=%d 记录：%s',k,file);
idx=table2array(row(1,2:min(width(row),1+k)));
idx=double(idx(isfinite(idx)));
idx=idx(:)';
assert(numel(idx)==k,'k=%d 对应的有效特征编号数量不是%d。',k,k);
end

function names=all_feature_names()
imu=["mean_abs","root_sum_squares","std_population","q25_abs","q50_abs", ...
    "q75_abs","iqr_abs","diff_l2","waveform_length","zero_cross_thr5", ...
    "kurtosis","skewness","sd2_expression","rel_power_band1","rel_power_band2", ...
    "rel_power_band3","rel_power_band4","rel_power_band5","psd_rank80_frequency", ...
    "psd_rank90_frequency","peak_frequency","max_psd","median_frequency", ...
    "mean_frequency","psd_std"];
emg=["mean_abs","root_sum_squares","std_population","energy","waveform_length", ...
    "zero_cross_thr50","hist_0_0p4","hist_0p4_0p8","hist_0p8_1p2", ...
    "hist_1p2_1p6","hist_1p6_90","rel_power_0_25","rel_power_25_50", ...
    "rel_power_50_75","rel_power_75_100","median_frequency","mean_frequency", ...
    "psd_rank80_frequency","psd_rank90_frequency","peak_frequency","max_psd"];
names=["acc_"+imu,"gyr_"+imu,"emg_"+emg];
end
