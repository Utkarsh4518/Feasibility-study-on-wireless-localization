function save_config(cfg, filepath)
% SAVE_CONFIG  Save configuration struct to a .mat file for reproducibility.
%
% save_config(cfg, filepath)
%
% Inputs:
%   cfg     - Config struct (e.g. from localization_config() or load_config)
%   filepath - Path for .mat file (e.g. 'configs/experiment_01.mat')
%
% The saved file can be loaded with load_config(filepath) and passed to
% run_experiment(load_config(filepath)) to rerun the experiment with the
% same parameters.
%
% Example:
%   cfg = localization_config();
%   cfg.enable_rtt = false;
%   cfg.noise_aoa_std_deg = 5;
%   save_config(cfg, 'configs/low_aoa_noise.mat');
%   run_experiment(load_config('configs/low_aoa_noise.mat'));

config = cfg; %#ok<NASGU>
save(filepath, 'config');
fprintf('Config saved to %s\n', filepath);
end
