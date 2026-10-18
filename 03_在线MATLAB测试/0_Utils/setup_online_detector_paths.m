function root=setup_online_detector_paths(root)
%SETUP_ONLINE_DETECTOR_PATHS 校验并优先添加当前项目的明确模块目录。
if nargin<1 || isempty(root), root=fileparts(fileparts(mfilename('fullpath'))); end
root=validate_tjx_path(root,'read',true);
folders={'0_State','0_Utils','1_Main','2_Config','3_Buffers','4_Filters', ...
    '5_Motion','6_EMG_Quality','7_Features','8_SVM','9_PostProcess'};
for i=numel(folders):-1:1
    folder=validate_tjx_path(fullfile(root,folders{i}),'read',true);
    addpath(folder,'-begin');
end
end
