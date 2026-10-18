function canonical=validate_tjx_path(path_value,access_mode,must_exist)
%VALIDATE_TJX_PATH 以默认拒绝原则校验 TJX 文件访问的规范化路径。
% access_mode 可为读取、写入或执行；MATLAB 安装目录仅允许读取和执行。
if nargin<2, access_mode='read'; end
if nargin<3, must_exist=true; end
assert((ischar(path_value)||isstring(path_value))&&isscalar(string(path_value)), ...
    'Path must be one explicit scalar path.');
raw=char(string(path_value)); assert(~isempty(strtrim(raw)),'Path cannot be empty.');
assert(isempty(regexp(raw,'[*?]','once')),'Unresolved wildcards are not allowed.');
f=java.io.File(raw);
if must_exist, assert(f.exists(),'Path does not exist: %s',raw); end
if ~f.exists()
    parent=f.getParentFile(); assert(~isempty(parent)&&parent.exists(), ...
        'An existing parent is required for a new target: %s',raw);
end
canonical=char(f.getCanonicalPath());
rw_roots={'C:\Users\TJX','F:\TJX','G:\TJX'};
matlab_root='C:\Program Files\MATLAB';
is_rw=any(cellfun(@(r)is_under(canonical,r),rw_roots));
is_matlab=is_under(canonical,matlab_root);
mode=lower(string(access_mode));
if mode=="write" || mode=="delete" || mode=="move"
    assert(is_rw,'Write access denied outside TJX personal roots: %s',canonical);
else
    assert(is_rw||is_matlab,'Read/execute access denied: %s',canonical);
end
end
function tf=is_under(candidate,root)
c=char(java.io.File(candidate).getCanonicalPath());
r=char(java.io.File(root).getCanonicalPath());
if strcmpi(c,r), tf=true; return, end
tf=startsWith(lower(c),[lower(r) filesep]);
end
