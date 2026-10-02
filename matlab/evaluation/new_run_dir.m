function runDir = new_run_dir(repoRoot, tag)
% NEW_RUN_DIR  Create results/<timestamp>[_tag] and return its path.
%
% runDir = new_run_dir(repoRoot)
% runDir = new_run_dir(repoRoot, 'montecarlo')
%
% If the folder already exists (two runs in the same second) a numeric suffix
% is appended so no earlier result is overwritten.

stamp = char(datetime('now', 'Format', 'yyyyMMdd_HHmmss'));
if nargin >= 2 && ~isempty(tag)
    stamp = [stamp '_' tag];
end
base = fullfile(repoRoot, 'results', stamp);
runDir = base;
i = 1;
while isfolder(runDir)
    i = i + 1;
    runDir = sprintf('%s_%d', base, i);
end
mkdir(runDir);
end
