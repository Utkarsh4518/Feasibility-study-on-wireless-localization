classdef TestEvaluation < matlab.unittest.TestCase
    % Error statistics, percentiles and the Cramer-Rao bound.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(root);
            setup_paths();
        end
    end

    methods (Test)
        function errorStatsKnownVector(tc)
            errs.a = [0.1 0.2 0.3 0.4 NaN 1.0]';
            stats = compute_error_stats(errs, struct('target_error_m', 0.5));
            tc.verifyEqual(stats.a.n, 5);
            tc.verifyEqual(stats.a.mean_err, 0.4, 'AbsTol', 1e-12);
            tc.verifyEqual(stats.a.median_err, 0.3, 'AbsTol', 1e-12);
            tc.verifyEqual(stats.a.frac_under_target, 0.8, 'AbsTol', 1e-12);
            tc.verifyEqual(stats.a.max_err, 1.0);
        end

        function allNaNMethodIsOmitted(tc)
            errs.a = [NaN NaN];
            errs.b = [1 2];
            stats = compute_error_stats(errs, struct('target_error_m', 0.5));
            tc.verifyFalse(isfield(stats, 'a'));
            tc.verifyTrue(isfield(stats, 'b'));
        end

        function percentileMatchesLinearInterpolation(tc)
            tc.verifyEqual(simple_percentile([1 2 3 4], 50), 2.5, 'AbsTol', 1e-12);
            tc.verifyEqual(simple_percentile([1 2 3 4], 90), 3.7, 'AbsTol', 1e-12);
            tc.verifyTrue(isnan(simple_percentile([], 50)));
        end

        function tCriticalValues(tc)
            tc.verifyEqual(t_crit95(9), 2.262, 'AbsTol', 1e-9);
            tc.verifyEqual(t_crit95(1000), 1.96);
            tc.verifyTrue(isnan(t_crit95(0)));
        end

        function crlbOrthogonalRangesClosedForm(tc)
            % Agent at origin, anchors on the axes: J = I/s^2, bound = sqrt(2)*s.
            cfg = localization_config();
            cfg.enable_rss = false;
            cfg.enable_aoa = false;
            cfg.use_ble = false;
            cfg.anchor_pos = [3 0; 0 4];
            s = cfg.speed_of_light * cfg.channel.wifi.rtt_std_s / 2;
            b = compute_crlb_over_time(cfg, 0, 0);
            tc.verifyEqual(b, sqrt(2) * s, 'RelTol', 1e-6);
        end

        function fisherRssMatchesHandFormula(tc)
            cfg = localization_config();
            cfg.enable_rtt = false;
            cfg.enable_aoa = false;
            cfg.use_ble = false;
            cfg.anchor_pos = [0 0; 10 0];
            ch = cfg.channel.wifi;
            px = 2; py = 3;
            lambda = 10 * ch.n / log(10);
            expected = zeros(2);
            for ax = [0 10]
                d = [px - ax; py];
                expected = expected + lambda ^ 2 / ch.rss_std_dB ^ 2 * (d * d') / (d' * d) ^ 2;
            end
            tc.verifyEqual(fisher_information(cfg, px, py), expected, 'RelTol', 1e-9);
        end

        function crlbIsSingularOnCollinearAnchorsLine(tc)
            cfg = localization_config();
            cfg.enable_aoa = false;
            cfg.anchor_pos = [0 0; 5 0; 10 0];
            b = compute_crlb_over_time(cfg, 3, 0);   % agent on the anchor line
            tc.verifyTrue(isnan(b));
        end

        function crlbMapShapeAndFiniteInsideHull(tc)
            cfg = localization_config();
            xs = linspace(0.5, 3, 6);
            ys = linspace(0.5, 3, 4);
            Z = compute_crlb_map(cfg, xs, ys);
            tc.verifySize(Z, [4 6]);
            tc.verifyTrue(all(isfinite(Z(:))));
        end
    end
end
