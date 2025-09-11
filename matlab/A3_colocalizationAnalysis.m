clearvars, clc

% -------------------------------------------------------------------------
% 配置参数
% -------------------------------------------------------------------------
defaultFolder = 'E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region124\DATASET';
outputFolder = 'E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region124\RESULTS';

% 支持批量处理的通道
channels = ["wfa", "pv"];

% 共定位分析参数
minDist = 15;  % 共定位判断的最小距离阈值（像素）

% 设置是否跳过位移场和脑区注释
skipDisplacementFields = true;  % 设置为true跳过位移场
skipAnnotationVolume = true;     % 设置为true跳过脑区注释

% 手动输入regionid选项
useManualRegionID = true;       % 设置为true使用手动输入的regionid
manualRegionID = 124;           % 手动输入的regionid值（可以根据需要修改）

% 限制分析的切片数量（设置为0表示分析所有切片）
maxSlicesToAnalyze = 0;  % 设置为0表示分析所有切片
% -------------------------------------------------------------------------

%% 选择XML文件并加载切片信息
filter = [defaultFolder filesep '*.xml'];
tit = 'Select an INFO XML file';
[file,path] = uigetfile(filter,tit);

if file ~= 0
    xml = [path filesep file];
    sliceArray = allSlicesFromXml(xml);
    fprintf('成功加载XML文件: %s\n', file);
    fprintf('找到 %d 个切片\n', length(sliceArray));
else
    error('未选择XML文件。请选择一个有效的info.xml文件。');
end

%% 为每个通道生成细胞计数数据
fprintf('\n=== 开始生成细胞计数数据 ===\n');

% 存储每个通道的计数结果
channelResults = struct();

for chIdx = 1:length(channels)
    channelName = channels(chIdx);
    fprintf('\n--- 开始分析通道: %s ---\n', channelName);
    
    % 自动查找最新的模型文件
    modelPattern = sprintf('model_%s_*.mat', channelName);
    modelFiles = dir(fullfile(outputFolder, modelPattern));
    if isempty(modelFiles)
        modelFiles = dir(fullfile(defaultFolder, modelPattern));
    end
    if isempty(modelFiles)
        error('未找到通道 %s 的模型文件 (pattern: %s)', channelName, modelPattern);
    end
    [~, idx] = max([modelFiles.datenum]);
    randomForestModelPath = fullfile(modelFiles(idx).folder, modelFiles(idx).name);
    fprintf('加载模型: %s\n', randomForestModelPath);
    
    % 确定通道编号
    if isfield(sliceArray(1), 'channelNames')
        channelIdx = find(strcmpi(channelName, sliceArray(1).channelNames));
    else
        channelIdx = chIdx; % fallback
    end
    if isempty(channelIdx)
        error('通道 %s 未在XML中找到', channelName);
    end
    
    % 确定要分析的切片数量
    if maxSlicesToAnalyze > 0
        numSlicesToAnalyze = min(maxSlicesToAnalyze, length(sliceArray));
        fprintf('限制分析前 %d 个切片 (总共 %d 个切片)\n', numSlicesToAnalyze, length(sliceArray));
    else
        numSlicesToAnalyze = length(sliceArray);
        fprintf('分析所有 %d 个切片\n', numSlicesToAnalyze);
    end
    
    T = table();
    % 分析选定的切片
    for i = 1:numSlicesToAnalyze
        if sliceArray(i).valid == 0
            fprintf('切片: "%s" 标记为无效，跳过量化\n', sliceArray(i).name);
            continue;
        end

        fprintf('处理切片 %d/%d: %s\n', i, numSlicesToAnalyze, sliceArray(i).name);
        
        try
            % 使用简化的量化方法
            new_T = sliceArray(i).quantifyDotsSimple([], channelIdx, randomForestModelPath, ...
                'skipDisplacementFields', skipDisplacementFields, ...
                'skipAnnotationVolume', skipAnnotationVolume, ...
                'useManualRegionID', useManualRegionID, ...
                'manualRegionID', manualRegionID);
            
            if ~isempty(new_T)
                T = [T; new_T];
                fprintf('成功处理切片 %s，检测到 %d 个细胞\n', sliceArray(i).name, height(new_T));
            else
                fprintf('切片 %s 中未检测到细胞\n', sliceArray(i).name);
            end
            
        catch ME
            fprintf('处理切片 %s 时出错: %s\n', sliceArray(i).name, ME.message);
            fprintf('继续处理下一个切片...\n');
            continue;
        end
    end

    % 存储结果
    channelResults.(channelName) = T;
    fprintf('通道 %s: 总共检测到 %d 个细胞\n', channelName, height(T));
end

%% 共定位分析
fprintf('\n=== 开始共定位分析 ===\n');

% 检查是否有足够的数据进行共定位分析
if ~isfield(channelResults, 'wfa') || ~isfield(channelResults, 'pv')
    error('缺少WFA或PV通道的数据，无法进行共定位分析');
end

wfaData = channelResults.wfa;
pvData = channelResults.pv;

fprintf('WFA数据: %d 个细胞\n', height(wfaData));
fprintf('PV数据: %d 个细胞\n', height(pvData));

% 获取所有唯一的图像
wfaImages = unique(wfaData.parentImg);
pvImages = unique(pvData.parentImg);

% 提取基础图像名称（去掉通道标识）
wfaBaseImages = cellfun(@(x) strrep(x, '-C1.tif', ''), wfaImages, 'UniformOutput', false);
pvBaseImages = cellfun(@(x) strrep(x, '-C2.tif', ''), pvImages, 'UniformOutput', false);

% 找到共同的基础图像名称
commonBaseImages = intersect(wfaBaseImages, pvBaseImages);

fprintf('找到 %d 个唯一图像\n', length(commonBaseImages));
fprintf('WFA图像: %s\n', strjoin(wfaImages, ', '));
fprintf('PV图像: %s\n', strjoin(pvImages, ', '));
fprintf('共同基础图像: %s\n', strjoin(commonBaseImages, ', '));

% 初始化结果表格
colocalizationResults = table();

for imgIdx = 1:length(commonBaseImages)
    baseImageName = commonBaseImages{imgIdx};
    fprintf('分析基础图像: %s\n', baseImageName);
    
    % 构建对应的C1和C2通道图像名称
    wfaImageName = [baseImageName, '-C1.tif'];
    pvImageName = [baseImageName, '-C2.tif'];
    
    % 获取当前图像的WFA和PV数据
    wfaInImage = wfaData(strcmp(wfaData.parentImg, wfaImageName), :);
    pvInImage = pvData(strcmp(pvData.parentImg, pvImageName), :);
    
    fprintf('  WFA数据 (%s): %d 个细胞\n', wfaImageName, height(wfaInImage));
    fprintf('  PV数据 (%s): %d 个细胞\n', pvImageName, height(pvInImage));
    
    if isempty(wfaInImage) || isempty(pvInImage)
        fprintf('  跳过图像 %s: 缺少WFA或PV数据\n', baseImageName);
        continue;
    end
    
    % 提取坐标
    coord_wfa = [wfaInImage.x, wfaInImage.y];
    coord_pv = [pvInImage.x, pvInImage.y];
    
    % 确保坐标为正数
    coord_wfa(coord_wfa < 1) = 1;
    coord_pv(coord_pv < 1) = 1;
    
    % 计算距离矩阵
    D = pdist2(coord_pv, coord_wfa, 'euclidean');
    D(D > minDist) = nan;
    [minDistances, minIndices] = min(D, [], 'omitnan');
    
    % 识别共定位的细胞
    colocalized_pv = pvInImage(minIndices(~isnan(minDistances)), :);
    colocalized_wfa = wfaInImage(~isnan(minDistances), :);
    notColocalized_wfa = wfaInImage(isnan(minDistances), :);
    notColocalized_pv = pvInImage(setdiff(1:height(pvInImage), minIndices(~isnan(minDistances))), :);
    
    num_colocalized = height(colocalized_pv);
    num_wfa_only = height(notColocalized_wfa);
    num_pv_only = height(notColocalized_pv);
    total_cells = num_colocalized + num_wfa_only + num_pv_only;
    
    fprintf('  共定位细胞: %d, 仅WFA: %d, 仅PV: %d, 总计: %d\n', ...
        num_colocalized, num_wfa_only, num_pv_only, total_cells);
    
    % 创建结果表格
    if total_cells > 0
        % 创建临时表格存储当前图像的结果
        tempTable = table('Size', [total_cells, 12], ...
            'VariableTypes', {'string', 'string', 'double', 'double', ...
            'double', 'double', 'double', 'double', ...
            'double', 'double', 'double', 'double'}, ...
            'VariableNames', {'cellID', 'parentImg', 'x', 'y', ...
            'wfa', 'fluoMeanWfa', 'fluoMedianWfa', 'areaPxWfa', ...
            'pv', 'fluoMeanPv', 'fluoMedianPv', 'areaPxPv'});
        
        % 生成细胞ID
        cellIDs = arrayfun(@(x) sprintf('%s_cell_%05d', baseImageName, x), ...
            1:total_cells, 'UniformOutput', false)';
        
        % 填充共定位细胞数据
        if num_colocalized > 0
            tempTable.cellID(1:num_colocalized) = cellIDs(1:num_colocalized);
            tempTable.parentImg(1:num_colocalized) = repmat(baseImageName, num_colocalized, 1);
            tempTable.x(1:num_colocalized) = round(mean([colocalized_wfa.x, colocalized_pv.x], 2));
            tempTable.y(1:num_colocalized) = round(mean([colocalized_wfa.y, colocalized_pv.y], 2));
            tempTable.wfa(1:num_colocalized) = ones(num_colocalized, 1);
            tempTable.pv(1:num_colocalized) = ones(num_colocalized, 1);
            tempTable{1:num_colocalized, ["fluoMeanWfa", "fluoMedianWfa", "areaPxWfa"]} = ...
                colocalized_wfa{:, ["fluoMean", "fluoMedian", "areaPx"]};
            tempTable{1:num_colocalized, ["fluoMeanPv", "fluoMedianPv", "areaPxPv"]} = ...
                colocalized_pv{:, ["fluoMean", "fluoMedian", "areaPx"]};
        end
        
        % 填充仅WFA细胞数据
        if num_wfa_only > 0
            startIdx = num_colocalized + 1;
            endIdx = num_colocalized + num_wfa_only;
            tempTable.cellID(startIdx:endIdx) = cellIDs(startIdx:endIdx);
            tempTable.parentImg(startIdx:endIdx) = repmat(baseImageName, num_wfa_only, 1);
            tempTable{startIdx:endIdx, {'x', 'y', 'fluoMeanWfa', 'fluoMedianWfa', 'areaPxWfa'}} = ...
                notColocalized_wfa{:, {'x', 'y', 'fluoMean', 'fluoMedian', 'areaPx'}};
            tempTable.wfa(startIdx:endIdx) = ones(num_wfa_only, 1);
            tempTable.pv(startIdx:endIdx) = zeros(num_wfa_only, 1);
        end
        
        % 填充仅PV细胞数据
        if num_pv_only > 0
            startIdx = num_colocalized + num_wfa_only + 1;
            endIdx = total_cells;
            tempTable.cellID(startIdx:endIdx) = cellIDs(startIdx:endIdx);
            tempTable.parentImg(startIdx:endIdx) = repmat(baseImageName, num_pv_only, 1);
            tempTable{startIdx:endIdx, {'x', 'y', 'fluoMeanPv', 'fluoMedianPv', 'areaPxPv'}} = ...
                notColocalized_pv{:, {'x', 'y', 'fluoMean', 'fluoMedian', 'areaPx'}};
            tempTable.wfa(startIdx:endIdx) = zeros(num_pv_only, 1);
            tempTable.pv(startIdx:endIdx) = ones(num_pv_only, 1);
        end
        
        % 添加到总结果中
        colocalizationResults = [colocalizationResults; tempTable];
    end
end

%% 保存结果
fprintf('\n=== 保存共定位分析结果 ===\n');

if isempty(colocalizationResults)
    fprintf('警告: 没有找到任何共定位数据。\n');
    fprintf('请检查您的数据和设置。\n');
else
    fprintf('总共分析了 %d 个细胞\n', height(colocalizationResults));
    
    % 统计结果
    num_colocalized_total = sum(colocalizationResults.wfa == 1 & colocalizationResults.pv == 1);
    num_wfa_only_total = sum(colocalizationResults.wfa == 1 & colocalizationResults.pv == 0);
    num_pv_only_total = sum(colocalizationResults.wfa == 0 & colocalizationResults.pv == 1);
    
    fprintf('共定位细胞总数: %d\n', num_colocalized_total);
    fprintf('仅WFA细胞总数: %d\n', num_wfa_only_total);
    fprintf('仅PV细胞总数: %d\n', num_pv_only_total);
    
    % 计算共定位率
    if num_colocalized_total + num_wfa_only_total > 0
        colocalization_rate_wfa = num_colocalized_total / (num_colocalized_total + num_wfa_only_total) * 100;
        fprintf('WFA细胞共定位率: %.2f%%\n', colocalization_rate_wfa);
    end
    
    if num_colocalized_total + num_pv_only_total > 0
        colocalization_rate_pv = num_colocalized_total / (num_colocalized_total + num_pv_only_total) * 100;
        fprintf('PV细胞共定位率: %.2f%%\n', colocalization_rate_pv);
    end
end

% 生成文件名
mouseID = sliceArray(1).mouseID;
timestamp = datestr(now, 'yyyymmdd-HHMMSS');

% 根据跳过的数据调整文件名后缀
if skipDisplacementFields && skipAnnotationVolume
    suffix = '_noAlign_noAnnot';
elseif skipDisplacementFields
    suffix = '_noAlign';
elseif skipAnnotationVolume
    suffix = '_noAnnot';
else
    suffix = '';
end

% 如果使用手动输入的regionid，添加到文件名中
if useManualRegionID
    suffix = [suffix '_manualRegion' num2str(manualRegionID)];
end

% 添加切片数量信息到文件名
if maxSlicesToAnalyze > 0
    sliceInfo = sprintf('_%dslices', numSlicesToAnalyze);
else
    sliceInfo = '';
end

filename = sprintf('%s_colocalization%s%s_%s.csv', mouseID, suffix, sliceInfo, timestamp);
filepath = fullfile(outputFolder, filename);

% 保存结果
try
    writetable(colocalizationResults, filepath);
    fprintf('共定位分析结果已保存到: %s\n', filepath);
    fprintf('文件包含 %d 个细胞，%d 个变量\n', height(colocalizationResults), width(colocalizationResults));
catch ME
    fprintf('保存文件时出错: %s\n', ME.message);
    fprintf('尝试手动保存...\n');
    
    % 提供手动保存选项
    [file, path] = uiputfile('*.csv', '保存共定位分析结果', fullfile(outputFolder, filename));
    if file ~= 0
        writetable(colocalizationResults, fullfile(path, file));
        fprintf('结果已手动保存到: %s\n', fullfile(path, file));
    else
        fprintf('分析结果未保存\n');
    end
end

%% 完成消息
beep;
fprintf('\n%s\n', repmat('*', 1, 50));
fprintf('*** 共定位分析完成 :D ***\n');
fprintf('%s\n', repmat('*', 1, 50));

if skipDisplacementFields
    fprintf('注意: 已跳过位移场分析\n');
end
if skipAnnotationVolume || useManualRegionID
    fprintf('注意: 使用简化的区域分析\n');
end

fprintf('分析参数:\n');
fprintf('  - 最小共定位距离: %d 像素\n', minDist);
fprintf('  - 分析的切片数: %d\n', numSlicesToAnalyze);
fprintf('  - 手动区域ID: %d\n', manualRegionID);
