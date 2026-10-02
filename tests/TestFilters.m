classdef TestFilters < matlab.unittest.TestCase
    % Smoothing, Kalman filter, EKF and fusion.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(root);
            setup_paths();
        end
    end

    methods (Test)
        function causalSmoothingUsesOnlyPast(tc)
            x = [0 0 0 10 10]';
            xc = smooth_rss_positions(x, x, 3, true);
            xm = smooth_rss_positions(x, x, 3, false);
            tc.verifyEqual(xc(4), mean([0 0 10]), 'AbsTol', 1e-12);
            tc.verifyEqual(xm(4), mean([0 10 10]), 'AbsTol', 1e-12);
        end

        function smoothingSkipsNaN(tc)
            x = [1 NaN 3]';
            xs = smooth_rss_positions(x, x, 3, false);
            tc.verifyTrue(all(isfinite(xs)));
        end

        function kalmanBeatsRawMeasurementsOnStraightLine(tc)
            cfg = localization_config();
            N = 80;
            dts = 0.2 * ones(N, 1);
            t = (0:N - 1)' * 0.2;
            x = 0.5 * t;
            y = 2 * ones(N, 1);
            rs = RandStream('mt19937ar', 'Seed', 0);
            zx = x + 0.2 * randn(rs, N, 1);
            zy = y + 0.2 * randn(rs, N, 1);
            R = repmat(0.04 * eye(2), [1 1 N]);
            [kx, ky, cov] = kalman_filter_cv(zx, zy, dts, cfg, R);
            errKf = hypot(kx - x, ky - y);
            errRaw = hypot(zx - x, zy - y);
            tc.verifyLessThan(mean(errKf(21:end)), mean(errRaw(21:end)));
            tc.verifyTrue(all(isfinite(cov(:, :, end)), 'all'));
        end

        function kalmanSurvivesNaNAndSustainedOffset(tc)
            cfg = localization_config();
            N = 60;
            dts = 0.2 * ones(N, 1);
            x = linspace(0, 3, N)';
            y = ones(N, 1);
            zx = x; zy = y;
            zx(10) = NaN;
            zx(30:40) = zx(30:40) + 5;
            R = repmat(0.04 * eye(2), [1 1 N]);
            [kx, ~, ~] = kalman_filter_cv(zx, zy, dts, cfg, R);
            tc.verifyTrue(isfinite(kx(10)));
            tc.verifyLessThan(abs(kx(end) - x(end)), 0.5);
        end

        function kalmanDoesNotNeedGroundTruth(tc)
            % kalman_filter_cv takes no truth argument: five inputs only.
            tc.verifyEqual(nargin('kalman_filter_cv'), 5);
        end

        function fusionHandlesNaNAndImproves(tc)
            N = 3;
            a.x = [1; NaN; 1]; a.y = [1; NaN; 1];
            a.cov = repmat(0.01 * eye(2), [1 1 N]);
            b.x = [1.2; 1.2; NaN]; b.y = [1.2; 1.2; NaN];
            b.cov = repmat(0.04 * eye(2), [1 1 N]);
            f = fuse_inverse_covariance({a, b}, N);
            expected = (1 / 0.01 * 1 + 1 / 0.04 * 1.2) / (1 / 0.01 + 1 / 0.04);
            tc.verifyEqual(f.x(1), expected, 'AbsTol', 1e-12);
            tc.verifyLessThan(f.cov(1, 1, 1), 0.01);
            tc.verifyEqual(f.x(2), 1.2, 'AbsTol', 1e-12);
            tc.verifyEqual(f.x(3), 1, 'AbsTol', 1e-12);
        end

        function ekfBeatsRttAloneOnSimulatedRun(tc)
            cfg = localization_config();
            meas = simulate_scenario(cfg, 3);
            res = analyze_run(meas, cfg);
            tc.verifyLessThan(mean(res.err.ekf), mean(res.err.rtt));
        end
    end
end
