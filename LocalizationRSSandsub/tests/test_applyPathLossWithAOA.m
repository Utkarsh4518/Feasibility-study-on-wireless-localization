%% TEST_APPLYPATHLOSSWITHAOA  Smoke test for path loss and AoA simulation.
%
% Runs applyPathLossWithAOA with a single agent/anchor pair and checks
% that outputs are finite and physically plausible. Does not change
% the algorithm; used for regression after refactoring.
%
% Usage: run from LocalizationRSSandsub (or ensure src/ is on path).

function test_applyPathLossWithAOA()
% Ensure signal_models is on path (repo root / signal_models)
thisDir = fileparts(mfilename('fullpath'));
repoRoot = fileparts(fileparts(thisDir));
addpath(fullfile(repoRoot, 'signal_models'));

tx_signal = 1;
agent_x = 2; agent_y = 3;
anchor_x = 0; anchor_y = 0;

[out, aoa_deg] = applyPathLossWithAOA(tx_signal, agent_x, agent_y, anchor_x, anchor_y);

% Attenuation: signal should be weaker than TX (positive path loss)
assert(abs(out) <= abs(tx_signal) + 1e-10, 'Attenuated signal should not exceed TX magnitude.');
assert(isfinite(out), 'Attenuated signal must be finite.');
assert(isfinite(aoa_deg), 'AoA must be finite.');
assert(aoa_deg >= 0 && aoa_deg <= 360, 'AoA should be in [0, 360] deg.');

fprintf('test_applyPathLossWithAOA: passed (out=%g, AoA_deg=%g)\n', out, aoa_deg);
end
