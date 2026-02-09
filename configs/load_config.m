function cfg = load_config(filepath, mergeWithDefaults)
% LOAD_CONFIG  Load configuration from a .mat file.
%
% cfg = load_config(filepath)
% cfg = load_config(filepath, mergeWithDefaults)
%
% Inputs:
%   filepath         - Path to .mat file containing variable 'cfg' or 'config'
%   mergeWithDefaults - (optional) If true, merge loaded struct with
%                       localization_config() so missing fields use defaults.
%                       Default: true
%
% Output:
%   cfg - Config struct suitable for run_experiment(cfg)
%
% To create a .mat config: save_config(localization_config(), 'my_exp.mat');
% Then rerun with: run_experiment(load_config('my_exp.mat'));

if nargin < 2
    mergeWithDefaults = true;
end

S = load(filepath);
if isfield(S, 'cfg')
    cfg = S.cfg;
elseif isfield(S, 'config')
    cfg = S.config;
else
    error('load_config:mat must contain variable ''cfg'' or ''config''.');
end

if mergeWithDefaults
    defaultCfg = localization_config();
    fn = fieldnames(defaultCfg);
    for k = 1:numel(fn)
        if ~isfield(cfg, fn{k})
            cfg.(fn{k}) = defaultCfg.(fn{k});
        end
    end
end
end
