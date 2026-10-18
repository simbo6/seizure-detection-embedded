function mat_files = find_target_mat_files(root_folder)
    % 功能：递归搜索根文件夹下所有人名文件夹，提取目标 .mat 文件路径
    % 输入：
    %   root_folder - 根文件夹路径（例如：'健康p1'）
    % 输出：
    %   mat_files - 包含所有需要处理的 .mat 文件路径的 cell 数组
    
    % 初始化.mat文件路径列表
    mat_files = {};
    
    % 获取根文件夹下的所有文件夹和文件
    folders = dir(root_folder);
    
    for i = 1:length(folders)
        % 只处理文件夹，并忽略隐藏文件夹
        if folders(i).isdir && ~startsWith(folders(i).name, '.')
            % 构建当前人名文件夹路径
            person_folder = fullfile(root_folder, folders(i).name);
            
            % 构建data文件夹路径
            data_folder = fullfile(person_folder, 'data');
            
            if exist(data_folder, 'dir')
                % 获取data文件夹中直接包含的所有.mat文件
                mat_files_in_data = dir(fullfile(data_folder, '*.mat'));
                for j = 1:length(mat_files_in_data)
                    mat_files{end+1} = fullfile(data_folder, mat_files_in_data(j).name); % 添加到列表
                end
            end
        end
    end
end

