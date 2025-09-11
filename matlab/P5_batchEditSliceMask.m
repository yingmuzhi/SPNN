%% P5_batchEditSliceMask.m - 批量编辑切片掩码
clearvars, clc

% --- 请在这里配置您的项目路径和鼠标ID ---
% base_path: 包含您所有鼠标文件夹的根目录
base_path = 'E:\_scj\20250903_FCY_SegPNN\src\output';
% mouse: 当前要处理的鼠标文件夹的名称
mouse = 'Mouse1Month8Region124';
% --- 配置结束 ---


%% 加载指定小鼠的所有切片
fprintf('正在为小鼠 "%s" 加载切片...\n', mouse);

% 构建 -info.xml 文件的路径
% 路径结构: base_path/mouse/DATASET/mouse/mouse-info.xml
xml_file_path = fullfile(base_path, mouse, 'DATASET', mouse, [mouse '-info.xml']);

if ~isfile(xml_file_path)
    error('找不到 -info.xml 文件: %s\n请先运行P3脚本生成该文件。', xml_file_path);
else
    fprintf('找到 -info.xml 文件: %s\n', xml_file_path);
    sliceArray = allSlicesFromXml(xml_file_path);
    fprintf('成功加载了 %d 个切片。\n', length(sliceArray));
end


%% (可选) - 运行此部分以预处理所有掩码
% 作用：移除小噪点、填充孔洞，并轻微腐蚀掩码边缘

% 小于此像素数的对象将被移除
threshold = 50;

for i = 1:length(sliceArray)
    msk = sliceArray(i).mask;
    temp = bwareaopen(msk,threshold);
    % Invert the mask and perform the same processing
    temp = bwareaopen(~temp,threshold);
    % Dilate the mask to erode a few pixels on the outside of the slice
    temp = imdilate(temp,strel('disk',3));
    % Invert back the mask to normal
    temp = ~temp;
    
    % Save the mask back into the objects
    sliceArray(i).mask = temp;
end

fprintf('\nMasks for all slices filtered.\n')

%% Run the maskEditor GUI on all the slices

% maskEditor(sliceArray);

%% (OPTIONAL) - Use this cell to show one specific slice
% 
% if ~exist('annotationVolume','var')
%     load('annotationVolume.mat');
% end
% 
% sl = Slice(7,xml);
% sl.show('volume',annotationVolume,'borders',true,'mask',true);

