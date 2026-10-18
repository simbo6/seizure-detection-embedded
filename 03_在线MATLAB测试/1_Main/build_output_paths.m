function p=build_output_paths(output_dir,hospital,patient,file_name,fold,feature_count,profile,app)
%BUILD_OUTPUT_PATHS 使用统一规则生成本项目的所有输出文件名。
if nargin<8 || isempty(app), app=online_project_config(); end
output_dir=validate_tjx_path(output_dir,'write',isfolder(output_dir));
[~,file_stem]=fileparts(char(file_name));
parts={hospital,patient,file_stem,char(profile)};
for i=1:numel(parts), parts{i}=sanitize(parts{i}); end
stem=sprintf(app.output.stem_format,parts{1},parts{2},parts{3},fold,feature_count,parts{4});
mat_file=validate_tjx_path(fullfile(output_dir,[stem app.output.mat_suffix]),'write',false);
points_file=validate_tjx_path(fullfile(output_dir,[stem app.output.points_suffix]),'write',false);
events_file=validate_tjx_path(fullfile(output_dir,[stem app.output.events_suffix]),'write',false);
summary_file=validate_tjx_path(fullfile(output_dir,[stem app.output.summary_suffix]),'write',false);
p=struct('directory',string(output_dir),'stem',string(stem), ...
    'mat',string(mat_file),'points',string(points_file),'events',string(events_file), ...
    'summary',string(summary_file));
end
function s=sanitize(x)
s=regexprep(char(string(x)),'[\\/:*?"<>| ]','_');
if isempty(s), s='unknown'; end
end
