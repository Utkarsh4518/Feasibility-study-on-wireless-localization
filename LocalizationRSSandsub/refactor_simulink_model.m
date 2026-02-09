%% REFACTOR_SIMULINK_MODEL  Rename blocks and add annotations for clarity.
%
% Run this script in MATLAB with the model on the path (e.g. cd to this folder).
% It renames blocks to meaningful names and adds annotations explaining
% signal flow. Save the model after running: save_system('Localization_Ependorfv2').
%
% Does NOT change connections or algorithm logic.
%
% See also: docs/SIMULINK_MODEL_GUIDE.md

modelName = 'Localization_Ependorfv2';

%% Load model (do not open if you want to run headless)
if bdIsLoaded(modelName)
    fprintf('Model %s already loaded.\n', modelName);
else
    load_system(modelName);
    fprintf('Loaded %s.\n', modelName);
end

%% ---- 1) Rename root-level subsystems ----
% Subsystem = channel + path loss + AoA + RTT (signal generation and noise)
try
    set_param([modelName '/Subsystem'], 'Name', 'Channel_And_Ranging');
    fprintf('  Renamed: Subsystem -> Channel_And_Ranging\n');
catch ME
    warning('Could not rename Subsystem: %s', ME.message);
end

%% ---- 2) Rename blocks inside Channel_And_Ranging (fix typos, clarify) ----
subName = [modelName '/Channel_And_Ranging'];
% Fix "Esimation" -> "Estimation"
renameMap = {
    'Esimation_WIFI_1',  'Estimation_WiFi_1'
    'Esimation_WIFI_2',  'Estimation_WiFi_2'
    'Esimation_WIFI_3',  'Estimation_WiFi_3'
    'Esimation_BLE_1',   'Estimation_BLE_1'
    'Esimation_BLE_2',   'Estimation_BLE_2'
    'Esimation_BLE_3',   'Estimation_BLE_3'
};
for k = 1:size(renameMap, 1)
    oldName = renameMap{k, 1};
    newName = renameMap{k, 2};
    try
        set_param([subName '/' oldName], 'Name', newName);
        fprintf('  Renamed: %s -> %s\n', oldName, newName);
    catch
        % Block may not exist or already renamed
    end
end

%% ---- 3) Rename blocks inside Agent (RSS estimators, trajectory) ----
agentName = [modelName '/Agent'];
% EstimateRSS, EstimateRSS  2, ... (note spaces in original names)
rssOldNew = {
    'EstimateRSS ',  'RSS_Estimator_WiFi_1'
    'EstimateRSS  2', 'RSS_Estimator_WiFi_2'
    'EstimateRSS  3', 'RSS_Estimator_WiFi_3'
    'EstimateRSS  4', 'RSS_Estimator_BLE_1'
    'EstimateRSS  5', 'RSS_Estimator_BLE_2'
    'EstimateRSS  6', 'RSS_Estimator_BLE_3'
};
for k = 1:size(rssOldNew, 1)
    oldName = rssOldNew{k, 1};
    newName = rssOldNew{k, 2};
    try
        set_param([agentName '/' oldName], 'Name', newName);
        fprintf('  Renamed: Agent/%s -> %s\n', oldName, newName);
    catch
    end
end
try
    set_param([agentName '/Agent_positioning'], 'Name', 'Ground_Truth_Trajectory');
    fprintf('  Renamed: Agent_positioning -> Ground_Truth_Trajectory\n');
catch
end
try
    set_param([agentName '/LocalizationSolver'], 'Name', 'Position_LS_Solver');
    fprintf('  Renamed: LocalizationSolver -> Position_LS_Solver\n');
catch
end

%% ---- 4) Add annotations (root level) ----
% Position [left, top, right, bottom]; place above/beside diagram
annRoot = [modelName '/Annotation_SignalFlow'];
try
    add_block('simulink/Common/Annotation', annRoot);
    set_param(annRoot, 'Text', [
        'SIGNAL FLOW (simulation only):' newline ...
        '1. Anchor 1/2/3: TX signals + positions' newline ...
        '2. Channel_And_Ranging: path loss, AoA, RTT, noise' newline ...
        '3. Agent: RSS/AoA/RTT -> Position_LS_Solver -> est_x, est_y' newline ...
        '   Ground_Truth_Trajectory -> true_x, true_y' newline ...
        'Outputs logged for MATLAB: true_x/y, est_x/y, RSS, AoA, RTT'
        ]);
    set_param(annRoot, 'Position', [50, -120, 400, 20]);
    fprintf('  Added root annotation: Annotation_SignalFlow\n');
catch ME
    warning('Could not add root annotation: %s', ME.message);
end

%% ---- 5) Annotation inside Channel_And_Ranging ----
annCh = [subName '/Annotation_Channel'];
try
    add_block('simulink/Common/Annotation', annCh);
    set_param(annCh, 'Text', [
        'Per-link: TX + agent pos -> path loss & noise -> RSS, AoA, RTT. ' ...
        'Estimation_WiFi_1..3 (WiFi), Estimation_BLE_1..3 (BLE).'
        ]);
    set_param(annCh, 'Position', [-80, -80, 200, -20]);
    fprintf('  Added annotation in Channel_And_Ranging\n');
catch
end

%% ---- 6) Annotation inside Agent ----
annAg = [agentName '/Annotation_Agent'];
try
    add_block('simulink/Common/Annotation', annAg);
    set_param(annAg, 'Text', [
        'RSS/AoA/RTT in -> RSS_Estimator_* -> Position_LS_Solver -> est_x, est_y. ' ...
        'Ground_Truth_Trajectory -> true_x, true_y.'
        ]);
    set_param(annAg, 'Position', [-900, 650, -500, 720]);
    fprintf('  Added annotation in Agent\n');
catch
end

fprintf('\nRefactor done. Save with: save_system(''%s'');\n', modelName);
% Uncomment to save automatically:
% save_system(modelName);
