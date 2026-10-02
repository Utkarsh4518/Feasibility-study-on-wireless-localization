function repoRoot = setup_paths()
% SETUP_PATHS  Add all project folders to the MATLAB path.
%
% repoRoot = setup_paths()
%
% Called by every entry point (run_experiment, run_simulated_experiment,
% run_monte_carlo, ...). Safe to call repeatedly.

repoRoot = fileparts(mfilename('fullpath'));
if isempty(repoRoot), repoRoot = pwd; end

folders = {'configs', 'signal_models', 'filters', 'estimators', 'evaluation', ...
           'ml', 'LocalizationRSSandsub'};
for i = 1:numel(folders)
    f = fullfile(repoRoot, folders{i});
    if isfolder(f)
        addpath(f);
    end
end
addpath(repoRoot);
end
