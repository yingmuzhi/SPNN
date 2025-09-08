%% 简单版本：从DATASET反推rawDATA
% 专门处理当前的情况，不依赖info.xml文件

clearvars, clc

%% 配置参数
datasetPath = 'E:\_scj\20250417_FCY\brainAlignment-main\brainAlignment-main\DATASET';
rawDataPath = 'E:\_scj\20250417_FCY\brainAlignment-main\brainAlignment-main\_testForPipeline\rawData\rawRGB';
mouse = 'AL1A';

%% 创建输出目录
mouseRawPath = fullfile(rawDataPath, mouse);
if ~exist(mouseRawPath, 'dir')
    mkdir(mouseRawPath);
    fprintf('创建目录: %s\n', mouseRawPath);
end

%% 获取hiRes目录中的所有图像文件
hiResPath = fullfile(datasetPath, mouse, 'hiRes');
if ~exist(hiResPath, 'dir')
    error('找不到hiRes目录: %s', hiResPath);
end

% 获取所有C1和C2文件
c1Files = dir(fullfile(hiResPath, '*-C1.tif'));
c2Files = dir(fullfile(hiResPath, '*-C2.tif'));

fprintf('找到 %d 个C1文件, %d 个C2文件\n', length(c1Files), length(c2Files));

%% 按切片名称分组文件
% 提取基础文件名（去掉-C1或-C2后缀）
c1BaseNames = cell(length(c1Files), 1);
c2BaseNames = cell(length(c2Files), 1);

for i = 1:length(c1Files)
    c1BaseNames{i} = strrep(c1Files(i).name, '-C1.tif', '');
end

for i = 1:length(c2Files)
    c2BaseNames{i} = strrep(c2Files(i).name, '-C2.tif', '');
end

% 找到匹配的切片
commonSlices = intersect(c1BaseNames, c2BaseNames);
fprintf('找到 %d 个完整的切片（包含C1和C2通道）\n', length(commonSlices));

%% 处理每个切片
fprintf('\n开始重建原始RGB图像...\n');

for sliceIdx = 1:length(commonSlices)
    sliceName = commonSlices{sliceIdx};
    
    % 构建文件路径
    c1Path = fullfile(hiResPath, sprintf('%s-C1.tif', sliceName));
    c2Path = fullfile(hiResPath, sprintf('%s-C2.tif', sliceName));
    
    % 检查文件是否存在
    if ~exist(c1Path, 'file') || ~exist(c2Path, 'file')
        fprintf('警告: 切片 %s 的某些通道文件不存在，跳过\n', sliceName);
        continue;
    end
    
    % 读取通道图像
    try
        c1Img = imread(c1Path);
        c2Img = imread(c2Path);
        
        % 确保图像尺寸一致
        if ~isequal(size(c1Img), size(c2Img))
            fprintf('警告: 切片 %s 的C1和C2通道尺寸不一致，跳过\n', sliceName);
            continue;
        end
        
        % 创建RGB图像
        % C1 -> 红色通道, C2 -> 绿色通道, 蓝色通道设为0
        rgbImg = zeros(size(c1Img, 1), size(c1Img, 2), 3, 'uint16');
        rgbImg(:,:,1) = c1Img;  % 红色通道 (C1)
        rgbImg(:,:,2) = c2Img;  % 绿色通道 (C2)
        rgbImg(:,:,3) = zeros(size(c1Img), 'uint16');  % 蓝色通道设为0
        
        % 保存RGB图像
        outputPath = fullfile(mouseRawPath, sprintf('%s.tif', sliceName));
        imwrite(rgbImg, outputPath);
        
        fprintf('已重建: %s (%dx%d)\n', sliceName, size(rgbImg, 1), size(rgbImg, 2));
        
    catch ME
        fprintf('错误: 处理切片 %s 时出错: %s\n', sliceName, ME.message);
        continue;
    end
end

%% 生成统计信息
finalFiles = dir(fullfile(mouseRawPath, '*.tif'));
fprintf('\n重建完成！\n');
fprintf('在 %s 中生成了 %d 个RGB图像文件\n', mouseRawPath, length(finalFiles));

%% 显示生成的文件列表
if length(finalFiles) <= 10
    fprintf('\n生成的文件列表:\n');
    for i = 1:length(finalFiles)
        fprintf('  %s\n', finalFiles(i).name);
    end
else
    fprintf('\n生成的文件列表 (显示前10个):\n');
    for i = 1:min(10, length(finalFiles))
        fprintf('  %s\n', finalFiles(i).name);
    end
    fprintf('  ... 还有 %d 个文件\n', length(finalFiles) - 10);
end

fprintf('\n原始数据重建完成！\n'); 