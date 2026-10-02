function [meas, res] = run_simulated_experiment(cfg)
% RUN_SIMULATED_EXPERIMENT  Same analysis as run_experiment, without Simulink.
%
% [meas, res] = run_simulated_experiment()
% [meas, res] = run_simulated_experiment(cfg)
%
% Generates RSS / AoA / RTT with simulate_scenario (the channel of the Simulink
% model, any anchor layout), then runs analyze_run and report_run. Fully seeded
% through cfg.random_seed, so repeated runs are identical, and independent of
% the global RNG.
%
% Unlike the Simulink path, the RSS-only position here is computed in MATLAB, so
% every method uses an independent measurement set and the fusion is a fair
% comparison.

repoRoot = setup_paths();
if nargin < 1 || isempty(cfg)
    cfg = localization_config();
end
cfg = validate_config(cfg);

meas = simulate_scenario(cfg);

runDir = '';
if cfg.save_evaluation_results
    runDir = new_run_dir(repoRoot, 'sim');
    save(fullfile(runDir, 'meas.mat'), 'meas', 'cfg');
end

res = analyze_run(meas, cfg);
report_run(res, cfg, runDir, 'Show', true);
end
