function ok = check_reproducibility(cfg)
% CHECK_REPRODUCIBILITY  Does seeding with rng() make the Simulink model repeatable?
%
% ok = check_reproducibility()
% ok = check_reproducibility(cfg)
%
% Runs the model twice with the same cfg.random_seed and compares the logged
% outputs. The noise in the model comes from randn() inside MATLAB Function
% blocks; whether rng() seeds those depends on the MATLAB/Simulink release and
% model settings, so this should be run once on your machine.
%
% If it reports a mismatch, use run_simulated_experiment / run_monte_carlo for
% reproducible results: simulate_scenario uses its own RandStream.

setup_paths();
if nargin < 1 || isempty(cfg)
    cfg = localization_config();
end
cfg = validate_config(cfg);
if isempty(cfg.random_seed)
    error('check_reproducibility:seed', 'cfg.random_seed is empty; nothing to check.');
end

load_system(cfg.modelName);
rng(cfg.random_seed);
a = sim(cfg.modelName);
rng(cfg.random_seed);
b = sim(cfg.modelName);

fields = {'true_x', 'true_y', 'est_x', 'est_y'};
maxdiff = 0;
sameLen = true;
for i = 1:numel(fields)
    x = a.(fields{i})(:);
    y = b.(fields{i})(:);
    if numel(x) ~= numel(y)
        sameLen = false;
        continue;
    end
    maxdiff = max(maxdiff, max(abs(x - y)));
end

ok = sameLen && maxdiff == 0;
if ok
    fprintf('Reproducible: two runs with seed %d are identical.\n', cfg.random_seed);
else
    fprintf(['NOT reproducible: max |difference| in est/true = %g (same length: %d).\n' ...
             'rng() does not control the Simulink noise here. For repeatable experiments use\n' ...
             'run_simulated_experiment / run_monte_carlo (own RandStream, fully seeded).\n'], ...
             maxdiff, sameLen);
end
end
