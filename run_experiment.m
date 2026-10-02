function [out, res] = run_experiment(cfg)
% RUN_EXPERIMENT  Top-level entry: run the Simulink model, then analyse it.
%
% All behaviour is controlled by the configuration struct. Change only the
% config to rerun experiments (or load a .mat config).
%
% Usage:
%   run_experiment()                          % use localization_config()
%   run_experiment(cfg)                       % use provided config
%   run_experiment(load_config('exp.mat'))    % rerun from saved config
%   [out, res] = run_experiment(...);
%
% Steps:
%   1. validate cfg, seed the RNG, load the model
%   2. sync cfg.anchor_pos with the anchors stored in the model
%   3. sim() -> extract_simulink_measurements -> meas
%   4. save meas.mat in results/<timestamp>/ (so analyze_run can be repeated
%      without Simulink: see reanalyze_run)
%   5. analyze_run -> report_run (metrics, figures, CSV)
%
% Without Simulink use run_simulated_experiment (same analysis on a
% pure-MATLAB simulation of the same channel).
%
% Simulation only. No real-world data or hardware.

repoRoot = setup_paths();

if nargin < 1 || isempty(cfg)
    cfg = localization_config();
end
cfg = validate_config(cfg);

% Reproducibility: seed the global RNG. Whether the model's MATLAB Function
% blocks honour it must be checked once with check_reproducibility.
if ~isempty(cfg.random_seed)
    rng(cfg.random_seed);
    fprintf('Random seed set to %d.\n', cfg.random_seed);
end

load_system(cfg.modelName);
cfg = sync_anchors_with_model(cfg);

fprintf('Running simulation for model: %s\n', cfg.modelName);
out = sim(cfg.modelName);

meas = extract_simulink_measurements(out, cfg);
cfg = disable_missing_modalities(cfg, meas);

runDir = '';
if cfg.save_evaluation_results
    runDir = new_run_dir(repoRoot);
    save(fullfile(runDir, 'meas.mat'), 'meas', 'cfg');
end

res = analyze_run(meas, cfg);
report_run(res, cfg, runDir, 'Show', true);
end

function cfg = disable_missing_modalities(cfg, meas)
if cfg.enable_aoa && isempty(meas.aoa)
    warning('localization:signal', 'AoA signals missing: disabling AoA.');
    cfg.enable_aoa = false;
end
if cfg.enable_rtt && isempty(meas.rtt)
    warning('localization:signal', 'RTT signals missing: disabling RTT.');
    cfg.enable_rtt = false;
end
end
