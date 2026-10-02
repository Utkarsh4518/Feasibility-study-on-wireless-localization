function repoRoot = setup_paths()
% SETUP_PATHS  Add all project folders to the MATLAB path.
%
% repoRoot = setup_paths()
%
% Called by every entry point (run_experiment, run_simulated_experiment,
% run_monte_carlo, ...). Safe to call repeatedly. Returns the repository root
% (the folder that contains matlab/, simulink/, python/ and results/).

matlabRoot = fileparts(mfilename('fullpath'));
repoRoot = fileparts(matlabRoot);

folders = {fullfile(matlabRoot, 'configs'), fullfile(matlabRoot, 'signal_models'), ...
           fullfile(matlabRoot, 'filters'), fullfile(matlabRoot, 'estimators'), ...
           fullfile(matlabRoot, 'evaluation'), fullfile(repoRoot, 'simulink')};
for i = 1:numel(folders)
    if isfolder(folders{i})
        addpath(folders{i});
    end
end
addpath(matlabRoot);
end
