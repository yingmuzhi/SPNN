%% EXTRACTING TRAINING IMAGES FROM DATASET
clearvars, clc

%% INDICATE FILE FOLDER AND IMAGE PARAMETERS
% Note that the number of cells per animal can be higher due to
% rounding operations.

% miceFolder = 'D:\proj_PNN-Atlas\DATASET'; %UPDATE HERE
miceFolder = 'E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region2\DATASET';

cellPerMice = 15;
cellSize = 80; %cells will be extracted from a bounding box of side cellSide x cellSide  (Px)

% 支持同时处理多个通道
channels = ["wfa", "pv"];  % 可以添加更多通道
% channels = ["wfa"];      % 如果只想处理单个通道
% channels = ["pv"];       % 如果只想处理单个通道
% channels = ["channel1", "channel2", "channel3"];  % 对于三通道数据

%% RANDOMLY SAMPLE CELLS FROM DIFFERENT MICE AND DIFFERENT SLICES (very slow)
% Note that the number of cells per animal can be higher due to
% rounding operations.

contents = dir(miceFolder);          % Get the contents of the path
folders = contents([contents.isdir]); % Filter to keep only directories

% Exclude '.' and '..' special directories
miceList = folders(~ismember({folders.name}, {'.', '..'}));
miceList = {miceList.name};

fprintf('\n=== 开始处理 %d 个通道 ===\n', length(channels));

% 为每个通道完整处理（生成训练图像 + 标注）
for chIdx = 1:length(channels)
    channel = channels(chIdx);
    fprintf('\n--- 开始处理通道 %d/%d: %s ---\n', chIdx, length(channels), channel);
    
    % 创建训练文件夹
    trainingFolder = fullfile(miceFolder, sprintf('training_%s', channel));
    if ~isfolder(trainingFolder)
        mkdir(trainingFolder);
        fprintf('创建训练文件夹: %s\n', trainingFolder);
    end
    
    indabs = 1;
    for mouseIdx = 1:length(miceList)
        
        mouseName = miceList{mouseIdx};
        mouseFolder = fullfile(miceFolder, mouseName);
        
        % 检查必要的文件夹是否存在
        hiResFolder = fullfile(mouseFolder, 'hiRes');
        countsFolder = fullfile(mouseFolder, 'counts');
        
        if ~isfolder(hiResFolder) || ~isfolder(countsFolder)
            fprintf('跳过 %s: 缺少必要的文件夹\n', mouseName);
            continue;
        end
        
        % 获取图像和计数文件
        imageFiles = dir(fullfile(hiResFolder, '*.tif'));
        countFiles = dir(fullfile(countsFolder, '*.csv'));
        
        if isempty(imageFiles) || isempty(countFiles)
            fprintf('跳过 %s: 没有找到图像或计数文件\n', mouseName);
            continue;
        end
        
        % 根据通道选择文件
        if strcmpi(channel, "wfa")
            % 选择C1通道的文件
            imageFiles = imageFiles(contains({imageFiles.name}, '-C1'));
            countFiles = countFiles(contains({countFiles.name}, '-cells_C1'));
        elseif strcmpi(channel, "pv")
            % 选择C2通道的文件
            imageFiles = imageFiles(contains({imageFiles.name}, '-C2'));
            countFiles = countFiles(contains({countFiles.name}, '-cells_C2'));
        else
            error('不支持的通道: %s', channel);
        end
        
        if isempty(imageFiles) || isempty(countFiles)
            fprintf('跳过 %s: 没有找到 %s 通道的文件\n', mouseName, channel);
            continue;
        end
        
        % 计算每个切片的细胞数量
        numSlices = length(imageFiles);
        cellPerSlice = ceil(cellPerMice / numSlices);
        
        fprintf('处理 %s (%s): %d 个切片, 每个切片 %d 个细胞\n', mouseName, channel, numSlices, cellPerSlice);
        
        for sliceIdx = 1:numSlices
            if sliceIdx > length(countFiles)
                fprintf('跳过切片 %d: 没有对应的计数文件\n', sliceIdx);
                continue;
            end
            
            % 读取图像
            imagePath = fullfile(hiResFolder, imageFiles(sliceIdx).name);
            im = imread(imagePath);
            
            % 读取细胞计数
            countPath = fullfile(countsFolder, countFiles(sliceIdx).name);
            try
                cellTab = readtable(countPath);
            catch ME
                fprintf('读取计数文件失败 %s: %s\n', countPath, ME.message);
                continue;
            end
            
            if height(cellTab) == 0
                fprintf('跳过切片 %d: 没有细胞数据\n', sliceIdx);
                continue;
            end
            
            % 随机选择细胞
            numCellsToExtract = min(cellPerSlice, height(cellTab));
            cellIdx = randsample(height(cellTab), numCellsToExtract);
            cells = cellTab{cellIdx, :};
            cells = uint16(cells);
            
            % 提取细胞图像并保存
            for i = 1:size(cells, 1)
                try
                    smallIm = extractSubImage(im, cells(i,:), cellSize);
                    
                    % 文件名定义
                    cellCode = sprintf("%04d", indabs);
                    mouseCode = sprintf("_m%02d", mouseIdx);
                    channelCode = strcat("_", channel);
                    smallImPath = fullfile(trainingFolder, sprintf("cell_%s%s%s.tif", cellCode, mouseCode, channelCode));
                    
                    imwrite(smallIm, smallImPath, 'Compression', 'lzw');
                    
                    indabs = indabs + 1;
                    
                    % 限制总数量
                    if indabs > 143
                        break;
                    end
                catch ME
                    fprintf('提取细胞 %d 失败: %s\n', i, ME.message);
                    continue;
                end
            end
            
            if indabs > 143
                break;
            end
        end
        
        fprintf("从小鼠 %d/%d 提取细胞完成 (%s) \n", mouseIdx, length(miceList), channel);
        
        if indabs > 143
            break;
        end
    end
    
    fprintf('通道 %s: 总共提取了 %d 个训练图像\n', channel, indabs - 1);
    
    % 立即为当前通道进行标注
    fprintf('开始标记通道 %s 的训练图像...\n', channel);
    try
        clab = cellLabeler(trainingFolder, channel, 1);
        fprintf('通道 %s 标记完成\n', channel);
    catch ME
        fprintf('通道 %s 标记失败: %s\n', channel, ME.message);
    end
    
    fprintf('--- 通道 %s 处理完成 ---\n', channel);
end

fprintf('\n=== 所有通道处理完成 ===\n');

% 显示最终处理总结
fprintf('\n最终处理总结:\n');
for chIdx = 1:length(channels)
    channel = channels(chIdx);
    trainingFolder = fullfile(miceFolder, sprintf('training_%s', channel));
    if isfolder(trainingFolder)
        files = dir(fullfile(trainingFolder, '*.tif'));
        fprintf('通道 %s: %d 个训练图像\n', channel, length(files));
    else
        fprintf('通道 %s: 训练文件夹不存在\n', channel);
    end
end



