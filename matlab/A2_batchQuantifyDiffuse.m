clearvars, clc

% -------------------------------------------------------------------------
defaultFolder = 'E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region124\DATASET';
outputFolder = 'E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region124\RESULTS';

channels = ["wfa", "pv"];
% channels = ["wfa"]; % 只处理wfa
% channels = ["pv"];  % 只处理pv

pixelSize = 0.414;       % in micrometers

% 设置是否跳过位移场和脑区注释
skipDisplacementFields = true;  % 设置为true跳过位移场
skipAnnotationVolume = true;     % 设置为true跳过脑区注释

% 手动输入regionid选项
useManualRegionID = true;       % 设置为true使用手动输入的regionid
manualRegionID = 124;           % 手动输入的regionid值（可以根据需要修改）

% 限制分析的切片数量（设置为0表示分析所有切片）
maxSlicesToAnalyze = 0;  % 设置为0表示分析所有切片
% -------------------------------------------------------------------------

%% Load all slices from a single XML info file (a mouse)

filter = [defaultFolder filesep '.xml'];
tit = 'Select an INFO XML file';
[file,path] = uigetfile(filter,tit);

if file ~= 0
    xml = [path filesep file];
    sliceArray = allSlicesFromXml(xml);
end

%% Diffuse fluorescence analysis for each channel

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
    
    % Initialize variables for the global fluorescence of each slice
    sliceName = cell(numSlicesToAnalyze,1);
    sliceFluo = zeros(numSlicesToAnalyze,1);
    
    % Analyze the first slice in the array
    fprintf('Processing slice 1/%d: %s\n', numSlicesToAnalyze, sliceArray(1).name);
    if sliceArray(1).valid == 0
        fprintf('Slice: "%s" flagged as not valid. Skipped quantification\n',sliceArray(1).name)
        % Initialize empty table for first slice
        T = table();
        sliceName{1} = sliceArray(1).name;
        sliceFluo(1) = 0;
    else
        % 使用简化的量化方法
        [T, totFluo] = sliceArray(1).quantifyDiffuseSimple(annotationVolume, channelIdx, ...
            'skipDisplacementFields', skipDisplacementFields, ...
            'skipAnnotationVolume', skipAnnotationVolume, ...
            'useManualRegionID', useManualRegionID, ...
            'manualRegionID', manualRegionID);
        sliceName{1} = sliceArray(1).name;
        sliceFluo(1) = totFluo;
    end
    
    % Analyze all the other slices
    for i = 2:numSlicesToAnalyze
        sliceName{i} = sliceArray(i).name;
        if sliceArray(i).valid == 0
            fprintf('Slice: "%s" flagged as not valid. Skipped quantification\n',sliceArray(i).name)
            continue
        end
        fprintf('Processing slice %d/%d: %s\n', i, numSlicesToAnalyze, sliceArray(i).name);
        [T_toAdd, totFluo] = sliceArray(i).quantifyDiffuseSimple(annotationVolume, channelIdx, ...
            'skipDisplacementFields', skipDisplacementFields, ...
            'skipAnnotationVolume', skipAnnotationVolume, ...
            'useManualRegionID', useManualRegionID, ...
            'manualRegionID', manualRegionID);
        sliceFluo(i) = totFluo;
        % Only merge if we have data from both tables
        if ~isempty(T) && ~isempty(T_toAdd)
            temp = outerjoin(T,T_toAdd,'Keys','regionID','MergeKeys',true);
            areaIdx = contains(temp.Properties.VariableNames, 'areaPx');
            fluoIdx = contains(temp.Properties.VariableNames, 'diffFluo');
            area = sum(temp{:,areaIdx}, 2, 'omitnan');
            fluo = sum(temp{:,fluoIdx}, 2, 'omitnan');
            T = temp(:,"regionID");
            T.areaPx = area;
            T.diffFluo = fluo;
        elseif isempty(T) && ~isempty(T_toAdd)
            T = T_toAdd;
        end
    end
    
    % Convert pixels in mm
    pizelSizeMm = pixelSize/1000;
    areaMm2 = T.areaPx * (pizelSizeMm^2);
    T.areaMm2 = areaMm2;
    
    % Add the Avg Intensity
    T.avgPxIntensity = T.diffFluo ./ T.areaPx;
    T = T(:,{'regionID','areaPx','areaMm2','diffFluo','avgPxIntensity'});
    
    % Create a secondary table with the average intensity for each slice
    Tslice = table(sliceName,sliceFluo,'VariableNames',{'sliceName','avgFluo'});
    
    % Print a happy end message
    beep
    fprintf(['\n' repmat('*',1,28)])
    fprintf('\n***  END OF ANALYSIS (%s)  :D ***\n', channelName)
    fprintf([repmat('*',1,28) '\n'])
    
    if isempty(T)
        fprintf('Warning: No regions were detected in any slice.\n');
        fprintf('Please check your data and settings.\n');
    else
        fprintf('Total regions detected: %d\n', height(T));
        fprintf('Total area analyzed: %.2f mm²\n', sum(T.areaMm2));
        fprintf('Total fluorescence: %.2f\n', sum(T.diffFluo));
    end
    
    if skipDisplacementFields
        fprintf('Note: Displacement fields were skipped.\n');
    end
    if skipAnnotationVolume || useManualRegionID
        fprintf('Note: Using simplified region analysis.\n');
    end
    
    %% Save the result of the analysis
    
    tit = sprintf('Save the analysis results for %s', channelName);
    filt = [defaultFolder filesep];
    
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
    
    fname = [sliceArray(1).mouseID '_diffFluo_' char(channelName) suffix sliceInfo datestr(now,'_yyyymmdd-HHMMSS') '.csv'];
    fnameSlice = [sliceArray(1).mouseID '_sliceFluo_' char(channelName) suffix sliceInfo datestr(now,'_yyyymmdd-HHMMSS') '.csv'];
    
    [file,path] = uiputfile('*.csv',tit,[outputFolder filesep fname]);
    if file ~= 0
        writetable(T, [path filesep file])
        writetable(Tslice, [path filesep fnameSlice])
        fprintf('Analysis saved in "%s".\n', [path file])
    else
        fprintf('Analysis NOT saved.\n')
    end
end

