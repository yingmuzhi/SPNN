%% P2_prepareMasks_Otsu.m
% 使用Otsu方法自动生成脑切片掩码，替代Ilastik软件
% 基于P2_prepareMasks.m的逻辑，但使用自动阈值分割

clearvars, clc

% --- 请在这里配置您的项目路径和鼠标ID ---
% base_path: 包含您所有鼠标文件夹的根目录
base_path = 'E:\_scj\20250903_FCY_SegPNN\src\output';
% mouse: 当前要处理的鼠标文件夹的名称
mouse = 'Mouse1Month8Region2';
% --- 配置结束 ---

%% 自动构建路径
mouse_root_path = fullfile(base_path, mouse);
dataset_parent_path = fullfile(mouse_root_path, 'DATASET'); % 这是包含所有鼠标数据文件夹的DATASET目录
mask_training_path = fullfile(mouse_root_path, 'mask_training'); % 训练样本也放在鼠标文件夹内

% 修正路径：在DATASET路径下，数据是存放在以mouse ID命名的子文件夹里的
thumbnailsPath = fullfile(dataset_parent_path, mouse, 'thumbnails');
masksPath = fullfile(dataset_parent_path, mouse, 'masks');


%% 步骤1：创建训练图像样本（可选，用于验证）
% 从thumbnails中随机采样图像块用于验证掩码质量
fprintf('步骤1：创建训练样本用于验证...\n');

% 创建训练样本目录
if ~exist(mask_training_path, 'dir')
    mkdir(mask_training_path);
    fprintf('创建训练样本目录: %s\n', mask_training_path);
end

% 获取所有thumbnails文件
if ~exist(thumbnailsPath, 'dir')
    error('找不到thumbnails目录: %s', thumbnailsPath);
end

% 获取所有thumb.png文件
thumbFiles = dir(fullfile(thumbnailsPath, '*-thumb.png'));
fprintf('找到 %d 个缩略图文件\n', length(thumbFiles));

% 创建训练样本（用于验证掩码质量）
numSamples = min(20, length(thumbFiles)); % 减少样本数量
cropSize = [300, 300];

if length(thumbFiles) > 0
    selIndices = randperm(length(thumbFiles), numSamples);
    
    for i = 1:numSamples
        imgPath = fullfile(thumbnailsPath, thumbFiles(selIndices(i)).name);
        im = imread(imgPath);
        
        if any(size(im, [1, 2]) < cropSize)
            continue;
        end
        
        % 随机裁剪
        imSmall = cropImg(im, cropSize);
        imOutName = fullfile(mask_training_path, sprintf('crop%02d.png', i));
        imwrite(imSmall, imOutName);
    end
    fprintf('生成了 %d 个训练样本\n', numSamples);
end

%% 步骤2：使用Otsu方法生成掩码
fprintf('\n步骤2：使用Otsu方法生成掩码...\n');

% 获取masks目录
if ~exist(masksPath, 'dir')
    mkdir(masksPath);
    fprintf('创建masks目录: %s\n', masksPath);
end

% 检查是否已有掩码文件
existingMasks = dir(fullfile(masksPath, '*.png'));
if ~isempty(existingMasks)
    fprintf('警告: masks目录已包含文件，将覆盖现有文件\n');
end

% 处理每个缩略图生成掩码
processedCount = 0;
for i = 1:length(thumbFiles)
    % 读取缩略图
    imgPath = fullfile(thumbnailsPath, thumbFiles(i).name);
    im = imread(imgPath);
    
    % 转换为灰度图
    if size(im, 3) == 3
        grayImg = rgb2gray(im);
    else
        grayImg = im;
    end
    
    % 使用Otsu方法进行阈值分割
    try
        % 计算Otsu阈值
        level = graythresh(grayImg);
        
        % 应用阈值生成二值掩码
        mask = imbinarize(grayImg, level);
        
        % 后处理：移除小物体和平滑边缘
        mask = postprocessMask(mask);
        
        % 生成输出文件名
        baseName = strrep(thumbFiles(i).name, '-thumb.png', '');
        maskFileName = sprintf('%s-mask.png', baseName);
        maskPath = fullfile(masksPath, maskFileName);
        
        % 保存掩码
        imwrite(mask, maskPath);
        
        processedCount = processedCount + 1;
        fprintf('已处理: %s -> %s\n', thumbFiles(i).name, maskFileName);
        
    catch ME
        fprintf('错误: 处理 %s 时出错: %s\n', thumbFiles(i).name, ME.message);
        continue;
    end
end

fprintf('\n掩码生成完成！\n');
fprintf('成功处理: %d/%d 个文件\n', processedCount, length(thumbFiles));

%% 步骤3：验证掩码质量
fprintf('\n步骤3：验证掩码质量...\n');

% 检查生成的掩码
generatedMasks = dir(fullfile(masksPath, '*-mask.png'));
fprintf('生成了 %d 个掩码文件\n', length(generatedMasks));

% 显示几个示例掩码
if length(generatedMasks) > 0
    fprintf('\n掩码文件列表:\n');
    for i = 1:min(5, length(generatedMasks))
        fprintf('  %s\n', generatedMasks(i).name);
    end
    if length(generatedMasks) > 5
        fprintf('  ... 还有 %d 个文件\n', length(generatedMasks) - 5);
    end
end

fprintf('\n所有步骤完成！\n');
fprintf('输入目录: %s\n', thumbnailsPath);
fprintf('输出目录: %s\n', masksPath);

%% 辅助函数

function crop = cropImg(bigIm, tileSize)
% crop = cropImg(bigIm, tileSize)
% 从大图像中随机裁剪指定大小的图像块
% bigIm    : 输入图像
% tileSize : 裁剪尺寸 [height, width]

tileX = ceil(tileSize(1)/2);
tileY = ceil(tileSize(2)/2);

% 确保裁剪区域在图像范围内
maxX = size(bigIm, 1) - tileX;
maxY = size(bigIm, 2) - tileY;

if maxX < tileX || maxY < tileY
    error('图像尺寸太小，无法裁剪指定大小的块');
end

% 随机选择裁剪中心
cropCenterX = randsample([tileX : maxX], 1);
cropCenterY = randsample([tileY : maxY], 1);

% 执行裁剪
crop = bigIm((cropCenterX-tileX+1):(cropCenterX+tileX-1), ...
              (cropCenterY-tileY+1):(cropCenterY+tileY-1), :);
end

function processedMask = postprocessMask(mask)
% processedMask = postprocessMask(mask)
% 对掩码进行后处理：移除小物体、平滑边缘等

% 移除小物体（面积小于100像素）
processedMask = bwareaopen(mask, 100);

% 填充小孔洞
processedMask = imfill(processedMask, 'holes');

% 形态学操作：先开运算再闭运算，平滑边缘
se = strel('disk', 3);
processedMask = imopen(processedMask, se);
processedMask = imclose(processedMask, se);

% 再次移除小物体
processedMask = bwareaopen(processedMask, 50);
end 