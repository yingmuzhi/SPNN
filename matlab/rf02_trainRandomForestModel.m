rmpath('E:\_scj\20250311_DIP\software\DIPimage 2.9\common\dipimage');
% TRAIN classifier for PNNs and PVs (multi-channel)
clc, clearvars

% 可批量处理的通道
channels = ["wfa", "pv"];

% 数据集根目录
basePath = "E:\_scj\20250903_FCY_SegPNN\src\output\Mouse1Month8Region124\DATASET";

% 通道参数（可根据需要调整）
channelParams = struct();
channelParams.wfa.cost = [0,1;3.5,0];
channelParams.wfa.minLeafSize = 50;
channelParams.wfa.numOfPixelsPerClass = 30;
channelParams.wfa.numOfTrees = 100;
channelParams.wfa.parallelSubset = 1;

channelParams.pv.cost = [0,1;4,0];
channelParams.pv.minLeafSize = 70;
channelParams.pv.numOfPixelsPerClass = 30;
channelParams.pv.numOfTrees = 100;
channelParams.pv.parallelSubset = 1;

for i = 1:length(channels)
    channel = channels(i);
    fprintf('\n=== 开始训练通道: %s ===\n', channel);
    trainFolder = fullfile(basePath, sprintf('training_%s', channel));
    if ~isfolder(trainFolder)
        warning('训练文件夹不存在: %s，跳过该通道', trainFolder);
        continue;
    end
    
    % 创建分类器
    rf = cellClassifier(channel);
    
    % 获取参数
    params = channelParams.(channel);
    
    % 训练
    rf.train(trainFolder, ...
        "contrastAdjustment", true, ...
        "cost", params.cost, ...
        "minLeafSize", params.minLeafSize, ...
        "numOfPixelsPerClass", params.numOfPixelsPerClass, ...
        "numOfTrees", params.numOfTrees, ...
        "parallelSubset", params.parallelSubset);
    
    % 可选：绘制OOB误差和特征重要性
    rf.plotOOBerror();
    rf.plotFeatureImportance();
    
    % 保存模型到DATASET目录下，文件名包含通道和时间戳
    modelName = sprintf('model_%s_%s.mat', channel, datestr(now,'yyyymmdd-HHMMSS'));
    modelPath = fullfile(basePath, modelName);
    rf.saveModel(modelPath);
    fprintf('通道 %s 模型已保存: %s\n', channel, modelPath);
end

fprintf('\n=== 所有通道训练完成 ===\n');
