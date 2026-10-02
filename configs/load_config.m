function cfg = load_config(filepath, mergeWithDefaults)
% LOAD_CONFIG  Load configuration from a .mat file.
%
% cfg = load_config(filepath)
% cfg = load_config(filepath, mergeWithDefaults)
%
% Inputs:
%   filepath          - Path to .mat file containing variable 'cfg' or 'config'
%   mergeWithDefaults - (optional) If true, fields missing from the loaded
%                       struct (including nested ones such as channel.ble.n)
%                       are filled from localization_config().
%                       Default: true
%
% Output:
%   cfg - Validated config struct suitable for run_experiment(cfg)
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
    error('load_config:format', 'Config .mat must contain variable ''cfg'' or ''config''.');
end

if mergeWithDefaults
    cfg = merge_structs(localization_config(), cfg);
end
cfg = validate_config(cfg);
end

function out = merge_structs(defaults, override)
% Recursively overlay "override" on "defaults" (override wins).
out = defaults;
fn = fieldnames(override);
for k = 1:numel(fn)
    f = fn{k};
    if isfield(defaults, f) && isstruct(defaults.(f)) && isstruct(override.(f))
        out.(f) = merge_structs(defaults.(f), override.(f));
    else
        out.(f) = override.(f);
    end
end
end
