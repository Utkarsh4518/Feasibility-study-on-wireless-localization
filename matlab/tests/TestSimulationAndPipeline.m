classdef TestSimulationAndPipeline < matlab.unittest.TestCase
    % Scenario generator and the end-to-end analysis on simulated data.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(root);
            setup_paths();
        end
    end

    methods (Test)
        function sameSeedSameMeasurements(tc)
            cfg = localization_config();
            a = simulate_scenario(cfg, 1);
            b = simulate_scenario(cfg, 1);
            c = simulate_scenario(cfg, 2);
            tc.verifyEqual(a.rtt.val, b.rtt.val);
            tc.verifyNotEqual(a.rtt.val, c.rtt.val);
        end

        function simulationDoesNotTouchGlobalRng(tc)
            cfg = localization_config();
            rng(5);
            a = rand;
            rng(5);
            simulate_scenario(cfg, 3);
            b = rand;
            tc.verifyEqual(a, b);
        end

        function trajectoryRespectsSpeedAndBounds(tc)
            cfg = localization_config();
            [t, x, y] = make_trajectory(cfg.trajectory);
            v = hypot(diff(x), diff(y)) ./ diff(t);
            tc.verifyLessThanOrEqual(max(v), cfg.trajectory.speed_mps + 1e-9);
            tc.verifyGreaterThanOrEqual(min(x), 0.8 - 1e-9);
            tc.verifyGreaterThanOrEqual(min(y), 0.8 - 1e-9);
        end

        function groupsHaveExpectedLinkLayout(tc)
            cfg = localization_config();
            m = simulate_scenario(cfg, 1);
            tc.verifyEqual(size(m.rtt.val, 2), 6);
            tc.verifyEqual(m.rtt.anchor, [1 2 3 1 2 3]);
            tc.verifyEqual(m.rtt.is_ble, logical([0 0 0 1 1 1]));
            tc.verifyEqual(size(m.aoa.val, 2), 3);
        end

        function fourAnchorLayoutWorks(tc)
            cfg = set_anchor_layout(localization_config(), 'four_corners');
            m = simulate_scenario(cfg, 1);
            tc.verifyEqual(size(m.rtt.val, 2), 8);
            res = analyze_run(m, cfg);
            tc.verifyTrue(all(isfinite(res.err.ekf)));
        end

        function zeroNoiseGivesExactGeometryEstimators(tc)
            cfg = localization_config();
            cfg.noise_scale = struct('rss', 0, 'aoa', 0, 'rtt', 0);
            res = analyze_run(simulate_scenario(cfg, 1), cfg);
            for key = {'rss', 'aoa', 'rtt', 'fusion'}
                tc.verifyLessThan(max(res.err.(key{1})), 1e-4);
            end
        end

        function disabledModalitiesAreNaN(tc)
            cfg = localization_config();
            cfg.enable_aoa = false;
            cfg.enable_rtt = false;
            res = analyze_run(simulate_scenario(cfg, 1), cfg);
            tc.verifyTrue(all(isnan(res.err.aoa)));
            tc.verifyTrue(all(isnan(res.err.rtt)));
            tc.verifyTrue(all(isfinite(res.err.rss)));
        end

        function methodOrderingWithModelAnchors(tc)
            cfg = localization_config();
            res = analyze_run(simulate_scenario(cfg, 7), cfg);
            m = @(k) mean(res.err.(k));
            tc.verifyLessThan(m('ekf'), m('rtt'));
            tc.verifyLessThan(m('rtt'), m('rss'));
            tc.verifyLessThan(m('fusion'), min(m('aoa'), m('rtt')));
            tc.verifyGreaterThan(mean(res.err.ekf <= cfg.target_error_m), 0.95);
        end

        function wrongAnchorsAreMuchWorse(tc)
            cfg = localization_config();
            meas = simulate_scenario(cfg, 7);
            good = analyze_run(meas, cfg);
            bad = cfg;
            bad.anchor_pos = [1 3; 5 7; 10 11];     % the old, wrong config values
            badRes = analyze_run(meas, bad);
            tc.verifyGreaterThan(mean(badRes.err.aoa), 10 * mean(good.err.aoa));
        end

        function inverseCovFusionBeatsFixedWeights(tc)
            cfg = localization_config();
            meas = simulate_scenario(cfg, 7);
            a = analyze_run(meas, cfg);
            cfg.fusion_method = 'fixed';
            b = analyze_run(meas, cfg);
            tc.verifyLessThan(mean(a.err.fusion), mean(b.err.fusion));
        end

        function monteCarloSummaryHasConfidenceIntervals(tc)
            cfg = localization_config();
            mc = run_monte_carlo(cfg, 4, 'Verbose', false);
            tc.verifyEqual(mc.n_runs, 4);
            tc.verifySize(mc.errors.ekf, [4, numel(mc.t)]);
            tc.verifyGreaterThan(mc.summary.ekf.mean_ci95, 0);
            tc.verifyLessThan(mc.summary.ekf.mean_err, mc.summary.rss.mean_err);
        end

        function sweepProducesOneRowPerValueAndMethod(tc)
            cfg = localization_config();
            T = run_sweep(cfg, 'noise_scale.aoa', [0.5 2], 3);
            tc.verifyEqual(height(T), 2 * 7);
            tc.verifyTrue(all(ismember(T.value_num, [0.5 2])));
            % more AoA noise -> larger AoA error
            e = @(v) T.mean_err(strcmp(T.method, 'aoa') & T.value_num == v);
            tc.verifyGreaterThan(e(2), e(0.5));
        end
    end
end
