%% P3_prepareXmlFiles.m - 创建元数据和信息文件

%% 步骤1：创建 miceData.xlsx
% 该文件包含项目中所有小鼠的元数据。
% 如果文件已存在，此部分将被跳过。

clc, clearvars

% --- 请在这里配置您的项目路径和鼠标ID ---
% base_path: 包含您所有鼠标文件夹的根目录
base_path = 'E:\_scj\20250903_FCY_SegPNN\src\output';
% mouse: 当前要处理的鼠标文件夹的名称
mouse = 'Mouse1Month8Region2';
% channelNames: 根据您的实验设置通道名称
% 例如: channelNames = ["wfa","pv"];
channelNames = ["wfa","pv","bf"];
% --- 配置结束 ---

fprintf('步骤1：检查/创建 miceData.xlsx...\n');

mice_data_file = fullfile(base_path, 'miceData.xlsx');

if ~isfile(mice_data_file)
    fprintf('未找到 miceData.xlsx，正在创建...\n');
    
    fileStruct = dir(base_path);
    miceArray = {};
    j = 1;
    for i = 1:size(fileStruct, 1)
        % 确保只添加目录，并排除 '.' 和 '..'
        if fileStruct(i).isdir && ~strcmp(fileStruct(i).name, '.') && ~strcmp(fileStruct(i).name, '..')
            miceArray{j} = fileStruct(i).name;
            j = j + 1;
        end
    end

    mices = string(miceArray)';
    
    if isempty(mices)
        error('在 base_path "%s" 中没有找到任何小鼠文件夹。', base_path);
    end

    miceT = table(mices, strings(size(mices,1),1), strings(size(mices,1),1), ...
        strings(size(mices,1),1), strings(size(mices,1),1), ...
        'VariableNames', {'mouseID', 'treatment', 'genotype', 'sex', 'age'});

    writetable(miceT, mice_data_file);
    fprintf('miceData.xlsx 已在 "%s" 中生成。\n', mice_data_file);
    disp('请手动填写该文件中的小鼠信息，然后重新运行此脚本。');
    return;
else
    fprintf('已找到 miceData.xlsx 文件。\n');
end


%% 步骤2：为指定小鼠创建 -info.xml 文件
fprintf('\n步骤2：为小鼠 "%s" 创建 -info.xml 文件...\n', mouse);

% 为当前小鼠构建数据路径
datasetPathForMouse = fullfile(base_path, mouse, 'DATASET', mouse);
if ~isfolder(datasetPathForMouse)
    error('找不到小鼠的数据集文件夹: %s', datasetPathForMouse);
end

% 读取总的实验信息文件
miceTable = readtable(mice_data_file);
vars = miceTable.Properties.VariableNames;
miceTable = varfun(@convertcolumn, miceTable);
miceTable.Properties.VariableNames = vars;

% 提取当前小鼠的信息
mouseTab = miceTable(string(miceTable.mouseID) == mouse, :);
if isempty(mouseTab)
    error('在 miceData.xlsx 中找不到小鼠ID "%s" 的信息。请检查文件内容。', mouse);
end
mouseStruct = table2struct(mouseTab);
mouseStruct.channelNames = channelNames;

% 提取切片信息
thumbnailsPath = fullfile(datasetPathForMouse, 'thumbnails');
if ~isfolder(thumbnailsPath)
    error('在 "%s" 中找不到 thumbnails 文件夹。', datasetPathForMouse);
end

[~,fn,~] = listfiles(thumbnailsPath,'.png');
if isempty(fn)
    error('在 thumbnails 文件夹中没有找到任何 .png 文件。');
end
slicesNames = erase(string(fn'),'-thumb.png');
fields = arrayfun(@(x) strsplit(x,'_'),slicesNames,'UniformOutput', false);
fields = cat(1,fields{:});
sliceNum = uint8(str2double(fields(:,2)));
well = fields(:,3);
flipped = zeros(size(fields, 1),1);
valid = ones(size(fields, 1),1);
slices = table2struct(table(slicesNames, sliceNum, well, flipped, valid, ...
    'VariableNames',{'name', 'number', 'well','flipped','valid'}))';

mouseStruct.slices = slices;

% Save -info.xml file
info_xml_path = fullfile(datasetPathForMouse, [mouse '-info.xml']);
writestruct(mouseStruct, info_xml_path);

fprintf('-info.xml 文件已成功保存至: %s\n', info_xml_path);
fprintf('\n所有步骤完成！\n');


%%


function column = convertcolumn(column)
   if iscell(column) && ~isempty(column) && iscell(column)
      column = string(column);
   end
end


