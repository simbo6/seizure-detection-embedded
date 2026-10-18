%% ====================== 可配置参数区（只改这里即可切换采样模式）======================
downsample_mode = 1;   % 1=不做下采样，使用全部原始样本；2=2倍降采样（原逻辑）
window_length = 6;     % 窗口长度（秒）
step_size = 1;         % 原始步长（秒）
%% ==================================================================================

% 定义根数据文件夹路径
rootFolder = 'G:\TJX\新整理的在线算法\data'; % 替换为你的实际数据文件夹路径
outputFolder = 'G:\TJX\新整理的在线算法\cross_output'; % 定义输出文件夹路径

% 创建5个分组文件夹（Fold1 到 Fold5）
for i = 1:5
    foldPath = fullfile(outputFolder, ['Fold' num2str(i)]);
    if ~exist(foldPath, 'dir')
        mkdir(foldPath);
    end
end
if ~exist(outputFolder, 'dir')
    mkdir(outputFolder);
end

% 加载分组信息（S31）
load('G:\TJX\新整理的在线算法\info\S31.mat', 'S31');
fprintf('S31 的大小: %d 行 %d 列\n', size(S31, 1), size(S31, 2));
disp('S31 的前几行内容:');
disp(S31(1:min(5, end), :));

% 初始化统计信息
total_files_processed = 0;
total_files_skipped = 0;
total_processed_files = 0;   % 找到的_processed.mat文件总数
patientsNotFound = {};
fileCounter = 1;             % 全局文件计数器（lab第七列）

% 遍历 S31，处理每个患者
for i = 1:size(S31, 1)
    patientName = S31{i, 1};          % 患者姓名
    if size(S31, 2) > 1
        hospitalName = S31{i, 2};      % 医院名称
    else
        hospitalName = '未知医院';
    end
    groupNumber = S31(i, 3);           % 分组号（1~5）

    % 构建患者文件夹路径
    patientFolder = fullfile(rootFolder, hospitalName, patientName);

    if exist(patientFolder, 'dir')
        fprintf('找到患者文件夹: %s\n', patientFolder);

        % 查找患者文件夹中的子目录
        subDataFolder = fullfile(patientFolder, 'data');
        if exist(subDataFolder, 'dir')
            files = dir(fullfile(subDataFolder, '*_processed*.mat'));
        else
            files = dir(fullfile(patientFolder, '*_processed*.mat'));
        end

        if isempty(files)
            fprintf('患者文件夹中没有匹配的 _processed.mat 文件: %s\n', patientFolder);
            total_files_skipped = total_files_skipped + 1;
        else
            fprintf('患者文件夹中的文件列表: \n');
            for k = 1:length(files)
                fprintf('  文件: %s\n', files(k).name);
                total_processed_files = total_processed_files + 1;
            end

            % 对每个 _processed.mat 文件进行处理
            for j = 1:length(files)
                sourceFile = fullfile(files(j).folder, files(j).name);
                data = load(sourceFile);

                if isfield(data, 'features') && isfield(data, 'bad_samples') && ...
                   isfield(data, 'label_index') && isfield(data, 'time_series')

                    features = data.features;
                    bad_samples = data.bad_samples;
                    label_index = data.label_index;
                    time_series = data.time_series;
                    % rm_values = data.rm_values; % 如有需要可保留

                    samples_count = size(features, 1);

                    % ===================== 分支判断下采样模式 =====================
                    if downsample_mode == 2
                        % 模式2：2倍降采样（原有逻辑）
                        downsample_idx = 2:2:samples_count;
                    elseif downsample_mode == 1
                        % 模式1：无下采样，使用全部样本
                        downsample_idx = 1:samples_count;
                    else
                        error('downsample_mode 只能设置为1或2！');
                    end
                    new_samples_count = length(downsample_idx);
                    features_remove = features(downsample_idx, :);
                    % ==============================================================

                    % 初始化 lab 矩阵（行数为新样本数，列数为7）
                    lab = zeros(new_samples_count, 7);

                    % 第七列：文件唯一标识（所有样本相同）
                    lab(:, 7) = fileCounter;
                    fileCounter = fileCounter + 1;

                    % 第一列：是否发作（根据降采样后的原始索引判断）
                    for l = 1:new_samples_count
                        orig_idx = downsample_idx(l);            % 当前样本在原始特征中的行号
                        start_time = (orig_idx - 1) * step_size + 1;
                        end_time = start_time + window_length - 1;

                        if end_time <= size(label_index, 1) && end_time <= size(time_series, 1)
                            if label_index(end_time, 1) == 1
                                lab(l, 1) = 1;
                            else
                                lab(l, 1) = 0;
                            end
                            % 时间戳转换（HHMMSS）
                            timeParts = sscanf(time_series(end_time), '%d:%d:%d');
                            lab(l, 4) = timeParts(1) * 1e4 + timeParts(2) * 1e2 + timeParts(3);
                        else
                            lab(l, 4) = NaN;
                        end
                    end

                    % 第二列：患者编号（使用S31的行号）
                    lab(:, 2) = i;

                    % 第三列：健康/患者标记
                    if contains(hospitalName, '健康P1')
                        lab(:, 3) = 0;   % 健康
                    else
                        lab(:, 3) = 1;   % 患者
                    end

                    % 第六列：合格标记（0合格，1不合格）
                    % 判断降采样后的索引是否在 bad_samples 中
                    lab(:, 6) = ismember(downsample_idx, bad_samples);

                    % 保存到对应的五折文件夹
                    [~, name, ~] = fileparts(files(j).name);
                    targetFile = fullfile(outputFolder, ['Fold' num2str(groupNumber)], [name, '_marked.mat']);
                    save(targetFile, 'features_remove', 'lab');
                    fprintf('处理并保存文件: %s 到 %s\n', sourceFile, targetFile);
                    total_files_processed = total_files_processed + 1;

                else
                    fprintf('文件缺少必要字段，跳过: %s\n', sourceFile);
                    total_files_skipped = total_files_skipped + 1;
                end
            end
        end
    else
        fprintf('患者文件夹不存在：%s\n', patientFolder);
        patientsNotFound{end+1} = patientName;
        total_files_skipped = total_files_skipped + 1;
    end
end

% 打印统计信息
fprintf('文件处理和组织完成！\n');
fprintf('总处理文件数: %d\n', total_files_processed);
fprintf('总跳过文件数: %d\n', total_files_skipped);
fprintf('找到的所有 _processed.mat 文件总数: %d\n', total_processed_files);
fprintf('生成的文件标识总数: %d\n', fileCounter-1);

if ~isempty(patientsNotFound)
    fprintf('以下患者文件夹未找到：\n');
    disp(patientsNotFound);
else
    fprintf('所有患者文件夹都已找到。\n');
end