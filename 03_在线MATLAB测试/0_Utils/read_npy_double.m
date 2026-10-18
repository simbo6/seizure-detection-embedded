function x=read_npy_double(file)
%READ_NPY_DOUBLE 用于读取小端 NumPy float64 数据的精简读取器。
file=validate_tjx_path(file,'read',true);
fid=fopen(file,'rb'); assert(fid>0,'Cannot open %s',file); c=onCleanup(@()fclose(fid));
magic=char(fread(fid,6,'*uint8')'); assert(strcmp(magic,char([147 'NUMPY'])),'Invalid npy: %s',file);
major=fread(fid,1,'uint8'); fread(fid,1,'uint8');
if major==1, hlen=fread(fid,1,'uint16','ieee-le'); else, hlen=fread(fid,1,'uint32','ieee-le'); end
hdr=char(fread(fid,hlen,'*uint8')');
tok=regexp(hdr,'''descr''\s*:\s*''([^'']+)''','tokens','once');
assert(~isempty(tok)&&(strcmp(tok{1},'<f8')||strcmp(tok{1},'|f8')),'Only float64 npy is supported.');
data=fread(fid,inf,'*double','ieee-le'); sh=regexp(hdr,'''shape''\s*:\s*\(([^\)]*)\)','tokens','once');
if isempty(sh), x=data; return, end
dims=sscanf(strrep(sh{1},',',' '),'%d')';
if isempty(dims), x=data; elseif numel(dims)==1, x=reshape(data,dims(1),1); else, x=reshape(data,dims); end
end
