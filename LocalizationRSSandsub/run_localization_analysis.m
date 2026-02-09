%% RUN_LOCALIZATION_ANALYSIS  Legacy entry: runs full pipeline via run_experiment.
%
% Ensures the repository root is on the path and calls run_experiment.
% Use this when your current directory is LocalizationRSSandsub/.
%
% For the canonical entry point, run from repository root:
%   run_experiment

function varargout = run_localization_analysis()
repoRoot = fileparts(fileparts(mfilename('fullpath')));
if isempty(repoRoot), repoRoot = pwd; end
addpath(repoRoot);
if nargout >= 2
    [varargout{1}, varargout{2}] = run_experiment();
elseif nargout == 1
    varargout{1} = run_experiment();
else
    run_experiment();
end
end
