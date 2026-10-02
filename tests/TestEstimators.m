classdef TestEstimators < matlab.unittest.TestCase
    % Position estimators recover the truth without noise and handle bad input.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(root);
            setup_paths();
        end
    end

    methods (Test)
        function rangesExactWithoutNoise(tc)
            A = [0 0; 0 5; 5 0];
            p = [2 1.5];
            r = hypot(p(1) - A(:, 1), p(2) - A(:, 2));
            [est, C] = estimate_position_ranges(A, r, 0.1 * ones(3, 1));
            tc.verifyEqual(est, p, 'AbsTol', 1e-6);
            tc.verifyTrue(all(isfinite(C(:))));
            tc.verifySize(C, [2 2]);
        end

        function rangesWithDuplicateAnchors(tc)
            A = [0 0; 0 5; 5 0; 0 0; 0 5; 5 0];
            p = [3 1];
            r = hypot(p(1) - A(:, 1), p(2) - A(:, 2));
            est = estimate_position_ranges(A, r, 0.1 * ones(6, 1));
            tc.verifyEqual(est, p, 'AbsTol', 1e-6);
        end

        function rangesIgnoreNaN(tc)
            % One of six WiFi+BLE links missing: all three anchors still observed.
            % (With only two ranges left the position is ambiguous: two mirror solutions.)
            A = [0 0; 0 5; 5 0; 0 0; 0 5; 5 0];
            p = [2 1.5];
            r = hypot(p(1) - A(:, 1), p(2) - A(:, 2));
            r(2) = NaN;
            est = estimate_position_ranges(A, r, 0.1 * ones(6, 1));
            tc.verifyEqual(est, p, 'AbsTol', 1e-6);
        end

        function rangesUnderdeterminedGivesNaN(tc)
            [p, C] = estimate_position_ranges([0 0; 0 0], [1; 1], [0.1; 0.1]);
            tc.verifyTrue(all(isnan(p)));
            tc.verifyTrue(all(isnan(C(:))));
        end

        function aoaExactWithoutNoise(tc)
            A = [0 0; 0 5; 5 0];
            p = [2 1.5];
            th = atan2(p(2) - A(:, 2), p(1) - A(:, 1));
            [est, C] = estimate_position_aoa_wls(A, th, 0.03 * ones(3, 1));
            tc.verifyEqual(est, p, 'AbsTol', 1e-9);
            tc.verifyTrue(all(isfinite(C(:))));
        end

        function aoaIgnoresMissingBearing(tc)
            A = [0 0; 0 5; 5 0];
            p = [2 1.5];
            th = atan2(p(2) - A(:, 2), p(1) - A(:, 1));
            th(2) = NaN;
            est = estimate_position_aoa_wls(A, th, 0.03 * ones(3, 1));
            tc.verifyEqual(est, p, 'AbsTol', 1e-9);
        end

        function rssRoundTripWithoutNoise(tc)
            cfg = localization_config();
            cfg.noise_scale = struct('rss', 0, 'aoa', 0, 'rtt', 0);
            meas = simulate_scenario(cfg, 1);
            k = 10;
            est = estimate_position_rss(cfg.anchor_pos, meas.rss, meas.rss.val(k, :), cfg);
            tc.verifyEqual(est, [meas.true_x(k), meas.true_y(k)], 'AbsTol', 1e-4);
        end
    end
end
