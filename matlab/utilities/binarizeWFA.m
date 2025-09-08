function mask = binarizeWFA(image)
% BINARIZEWFA - 为WFA通道生成初始二值化掩码
% 
% 输入:
%   image - uint8类型的输入图像
% 
% 输出:
%   mask - 逻辑类型的二值化掩码
%
% 这个函数为WFA染色图像生成初始的二值化掩码，用于cellLabeler工具
% 用户可以在标注界面中进一步修改这个掩码

    % 确保输入是uint8类型
    if ~isa(image, 'uint8')
        image = uint8(image);
    end
    
    % 使用Otsu方法进行自动阈值分割
    % 对于WFA染色，通常细胞区域较亮
    threshold = graythresh(image);
    
    % 应用阈值生成二值化掩码
    mask = imbinarize(image, threshold);
    
    % 进行形态学操作来清理掩码
    % 去除小的噪声点
    mask = bwareaopen(mask, 10);
    
    % 填充小的孔洞
    mask = imfill(mask, 'holes');
    
    % 可选：进行轻微的形态学开运算来平滑边界
    se = strel('disk', 2);
    mask = imopen(mask, se);
    
    % 确保输出是逻辑类型
    mask = logical(mask);
    
end

