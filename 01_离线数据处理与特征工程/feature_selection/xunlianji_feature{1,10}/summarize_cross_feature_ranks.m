%% 汇总五折 all_k_selected_features 的特征秩次
% 结果：
%   feature_rank_details.csv  每个 K、特征及五折秩次和平均秩次
%   feature_rank_topK.csv      每个 K 总体排名前 K 个特征

rootDir = fileparts(mfilename('fullpath'));
assertAllowedPath(rootDir, 'rw');

foldDirs = dir(fullfile(rootDir, '*cross'));
foldDirs = foldDirs([foldDirs.isdir]);
assert(~isempty(foldDirs), '未找到形如 *cross 的文件夹。');

allRows = table();
for f = 1:numel(foldDirs)
    foldPath = fullfile(rootDir, foldDirs(f).name);
    csvPath = fullfile(foldPath, 'all_k_selected_features.csv');
    assertAllowedPath(foldPath, 'r');
    assertAllowedPath(csvPath, 'r');
    assert(isfile(csvPath), '缺少文件：%s', csvPath);

    T = readtable(csvPath, 'VariableNamingRule', 'preserve');
    kName = T.Properties.VariableNames{1};
    kValues = T.(kName);
    featureCols = startsWith(string(T.Properties.VariableNames), 'FeatureIndex_');
    featureNames = T.Properties.VariableNames(featureCols);
    foldNo = str2double(regexp(foldDirs(f).name, '^\d+', 'match', 'once'));
    for i = 1:height(T)
        k = kValues(i);
        selected = T{i, featureCols};
        selected = selected{:,:};
        selected = selected(~isnan(selected));
        for rank = 1:numel(selected)
            row = table(k, foldNo, selected(rank), rank, ...
                'VariableNames', {'K','Fold','Feature','Rank'});
            allRows = [allRows; row]; %#ok<AGROW>
        end
    end
end

% 缺席特征按 K+1 计秩，表示该折未进入前 K；这样五折平均秩次可直接比较。
kList = unique(allRows.K);
featureList = unique(allRows.Feature);
summary = table();
for k = kList(:)'
    for feature = featureList(:)'
        ranks = nan(numel(foldDirs), 1);
        for j = 1:numel(foldDirs)
            hit = allRows.K == k & allRows.Fold == str2double(regexp(foldDirs(j).name, '^\d+', 'match', 'once')) & allRows.Feature == feature;
            if any(hit)
                ranks(j) = allRows.Rank(find(hit, 1));
            else
                ranks(j) = k + 1;
            end
        end
        row = table(k, feature, mean(ranks), sum(ranks), ...
            'VariableNames', {'K','Feature','MeanRank','RankSum'});
        row = [row, array2table(ranks', 'VariableNames', compose('Fold%dRank', 1:numel(foldDirs)))];
        summary = [summary; row]; %#ok<AGROW>
    end
end

summary = sortrows(summary, {'K','MeanRank','Feature'});
detailsPath = fullfile(rootDir, 'feature_rank_details.csv');
topPath = fullfile(rootDir, 'feature_rank_topK.csv');
assertAllowedPath(detailsPath, 'rw');
writetable(summary, detailsPath);

top = table();
for k = kList(:)'
    rows = summary(summary.K == k, :);
    rows = rows(1:min(k, height(rows)), :);
    rows.Rank = (1:height(rows))';
    top = [top; rows(:, [{'K','Rank','Feature','MeanRank','RankSum'}, ...
        cellstr(compose('Fold%dRank', 1:numel(foldDirs)))])]; %#ok<AGROW>
end
assertAllowedPath(topPath, 'rw');
writetable(top, topPath);
fprintf('已生成：\n%s\n%s\n', detailsPath, topPath);

function assertAllowedPath(pathValue, mode)
    p = string(java.io.File(char(pathValue)).getCanonicalPath());
    roots = ["C:\\Users\\TJX", "F:\\TJX", "G:\\TJX"];
    allowed = any(startsWith(lower(p), lower(roots) + "\\")) || any(strcmpi(p, roots));
    assert(allowed, '路径不在允许的 TJX 白名单内：%s', p);
    if mode == "r"
        assert(isfile(p) || isfolder(p), '读取路径不存在：%s', p);
    end
end
