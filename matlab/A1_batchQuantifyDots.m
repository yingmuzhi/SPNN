clearvars, clc

% -------------------------------------------------------------------------
defaultFolder = 'E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region124\DATASET';
outputFolder = 'E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region124\RESULTS';

% 支持批量处理的通道
channels = ["wfa", "pv"];
% channels = ["wfa"]; % 只处理wfa
% channels = ["pv"];  % 只处理pv

% 设置是否跳过位移场和脑区注释
skipDisplacementFields = true;  % 设置为true跳过位移场
skipAnnotationVolume = true;     % 设置为true跳过脑区注释

% 手动输入regionid选项
useManualRegionID = true;       % 设置为true使用手动输入的regionid
manualRegionID = 124;           % 手动输入的regionid值（可以根据需要修改）

% 限制分析的切片数量（设置为2表示只分析前2个切片）
maxSlicesToAnalyze = 0;  % 设置为0表示分析所有切片
% -------------------------------------------------------------------------

%% 检查并创建输出文件夹
if ~isfolder(outputFolder)
    mkdir(outputFolder);
    fprintf('创建输出文件夹: %s\n', outputFolder);
else
    fprintf('输出文件夹已存在: %s\n', outputFolder);
end

%% Load all slices from a single XML info file (a mouse)

filter = [defaultFolder filesep '.xml'];
tit = 'Select an INFO XML file';
[file,path] = uigetfile(filter,tit);

if file ~= 0
    xml = [path filesep file];
    sliceArray = allSlicesFromXml(xml);
else
    error('No XML file selected. Please select a valid info.xml file.');
end

%% Single dots analysis for each channel

% Load the annotation volume (optional)
annotationVolume = [];
if ~skipAnnotationVolume
    try
        if ~exist('annotationVolume','var')
            load(fullfile(pwd, "src", 'annotationVolume.mat'));
        end
        fprintf('Annotation volume loaded successfully.\n');
    catch ME
        fprintf('Warning: Could not load annotation volume: %s\n', ME.message);
        fprintf('Continuing without annotation data...\n');
        annotationVolume = [];
    end
else
    fprintf('Skipping annotation volume loading as requested.\n');
end

for chIdx = 1:length(channels)
    channelName = channels(chIdx);
    fprintf('\n=== 开始分析通道: %s ===\n', channelName);
    
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
        fprintf('Limiting analysis to first %d slices (out of %d total slices)\n', numSlicesToAnalyze, length(sliceArray));
    else
        numSlicesToAnalyze = length(sliceArray);
        fprintf('Analyzing all %d slices\n', numSlicesToAnalyze);
    end
    
    T = table();
    % Analyze selected slices
    for i = 1:numSlicesToAnalyze
        if sliceArray(i).valid == 0
            fprintf('Slice: "%s" flagged as not valid. Skipped quantification\n',sliceArray(i).name)
            continue
        end

        fprintf('Processing slice %d/%d: %s\n', i, numSlicesToAnalyze, sliceArray(i).name);
        
        try
            % 修改quantifyDots调用以处理缺失的位移场和注释数据
            if skipDisplacementFields || skipAnnotationVolume
                % 使用简化的量化方法
                new_T = sliceArray(i).quantifyDotsSimple(annotationVolume, channelIdx, randomForestModelPath, ...
                    'skipDisplacementFields', skipDisplacementFields, ...
                    'skipAnnotationVolume', skipAnnotationVolume, ...
                    'useManualRegionID', useManualRegionID, ...
                    'manualRegionID', manualRegionID);
            else
                % 使用原始方法
                new_T = sliceArray(i).quantifyDots(annotationVolume, channelIdx, randomForestModelPath);
            end
            
            if ~isempty(new_T)
                T = [T; new_T];
                fprintf('Successfully processed slice %s with %d cells\n', sliceArray(i).name, height(new_T));
            else
                fprintf('No cells detected in slice %s\n', sliceArray(i).name);
            end
            
        catch ME
            fprintf('Error processing slice %s: %s\n', sliceArray(i).name, ME.message);
            fprintf('Continuing with next slice...\n');
            continue;
        end
    end

    % Print a happy end message
    beep
    fprintf(['\n' repmat('*',1,28)])
    fprintf('\n***  END OF ANALYSIS (%s)  :D ***\n', channelName)
    fprintf([repmat('*',1,28) '\n'])

    if isempty(T)
        fprintf('Warning: No cells were detected in any slice.\n');
        fprintf('Please check your model and data.\n');
    else
        fprintf('Total cells detected: %d\n', height(T));
    end

    %% Save the result of the analysis
    
    tit = sprintf('Save the analysis results for %s', channelName);
    filt = [outputFolder filesep];

    % 根据跳过的数据调整文件名
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

    fname = [sliceArray(1).mouseID '_dots_' char(channelName) suffix sliceInfo datestr(now,'_yyyymmdd-HHMMSS') '.csv'];

    [file,path] = uiputfile('*.csv',tit,[outputFolder filesep fname]);
    if file ~= 0
        writetable(T, [path filesep file])
        fprintf('Analysis saved in "%s".\n', [path file])
        fprintf('File contains %d cells with %d variables.\n', height(T), width(T));
    else
        fprintf('Analysis NOT saved.\n')
    end
end

