%% Orchestrated pipeline runner for P1-P5, rf01-rf02, A1-A3
clearvars; clc;

% ----------------- User Config -----------------
regions = [6]; % e.g., [6 8 9]
baseOutput = 'E:\_scj\20250903_FCY_SegPNN\src\output';

% If you want to override channel mapping/order inside Python tif combiner,
% run it before this pipeline manually, or integrate here if needed.
% ------------------------------------------------

rootDir = fileparts(mfilename('fullpath'));
addpath(rootDir);
addpath(fullfile(rootDir, 'utilities'));

for ridx = 1:numel(regions)
    region = regions(ridx);
    mouse = sprintf('Mouse1Month8Region%d', region);
    defaultFolder = fullfile(baseOutput, mouse, 'DATASET');
    manualRegionID = region;

    fprintf('\n========== PIPELINE START: %s ==========' , mouse);

    % P1: prepare mouse folder (run twice as required)
    for p1run = 1:2
        try
            fprintf('\n[RUN] P1_prepareMouseFolder.m (pass %d/2)\n', p1run);
            run(fullfile(rootDir, 'P1_prepareMouseFolder.m'));
        catch ME
            warning('P1 (pass %d) failed: %s', p1run, ME.message);
        end
    end

    % P2: Otsu masks
    try
        fprintf('\n[RUN] P2_prepareMasks_Otsu.m\n');
        run(fullfile(rootDir, 'P2_prepareMasks_Otsu.m'));
    catch ME
        warning('P2 failed: %s', ME.message);
    end

    % P3: XML files
    try
        fprintf('\n[RUN] P3_prepareXmlFiles.m\n');
        run(fullfile(rootDir, 'P3_prepareXmlFiles.m'));
    catch ME
        warning('P3 failed: %s', ME.message);
    end

    % P5: optional slice mask edit (interactive)
    try
        fprintf('\n[RUN] P5_batchEditSliceMask.m\n');
        run(fullfile(rootDir, 'P5_batchEditSliceMask.m'));
    catch ME
        warning('P5 failed: %s', ME.message);
    end

    % rf01: generate training images and label
    try
        fprintf('\n[RUN] rf01_generateTrainingImages.m\n');
        miceFolder = defaultFolder; %#ok<NASGU>
        run(fullfile(rootDir, 'rf01_generateTrainingImages.m'));
    catch ME
        warning('rf01 failed: %s', ME.message);
    end

    % rf02: train random forest
    try
        fprintf('\n[RUN] rf02_trainRandomForestModel.m\n');
        run(fullfile(rootDir, 'rf02_trainRandomForestModel.m'));
    catch ME
        warning('rf02 failed: %s', ME.message);
    end

    % A1: quantify dots
    try
        fprintf('\n[RUN] A1_batchQuantifyDots.m\n');
        run(fullfile(rootDir, 'A1_batchQuantifyDots.m'));
    catch ME
        warning('A1 failed: %s', ME.message);
    end

    % A2: quantify diffuse
    try
        fprintf('\n[RUN] A2_batchQuantifyDiffuse.m\n');
        run(fullfile(rootDir, 'A2_batchQuantifyDiffuse.m'));
    catch ME
        warning('A2 failed: %s', ME.message);
    end

    % A3: colocalization analysis
    try
        fprintf('\n[RUN] A3_colocalizationAnalysis.m\n');
        run(fullfile(rootDir, 'A3_colocalizationAnalysis.m'));
    catch ME
        warning('A3 failed: %s', ME.message);
    end

    fprintf('\n========== PIPELINE END: %s =========\n' , mouse);
end

fprintf('\nAll requested regions finished.\n');


