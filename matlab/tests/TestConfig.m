classdef TestConfig < matlab.unittest.TestCase
    % Config validation, layouts, merge-on-load, signal-model smoke test.

    methods (TestClassSetup)
        function addPaths(~)
            root = fileparts(fileparts(mfilename('fullpath')));
            addpath(root);
            setup_paths();
        end
    end

    methods (Test)
        function defaultConfigIsValid(tc)
            cfg = localization_config();
            tc.verifyWarningFree(@() validate_config(cfg));
        end

        function defaultAnchorsMatchSimulinkModel(tc)
            cfg = localization_config();
            tc.verifyEqual(cfg.anchor_pos, [0 0; 0 5; 5 0]);
        end

        function badAnchorsRejected(tc)
            cfg = localization_config();
            cfg.anchor_pos = [0 0 0; 1 1 1];
            tc.verifyError(@() validate_config(cfg), 'localization:config');
            cfg.anchor_pos = [1 1; 1 1];
            tc.verifyError(@() validate_config(cfg), 'localization:config');
        end

        function badFusionWeightRejected(tc)
            cfg = localization_config();
            cfg.fusion_weight_kf = 1.5;
            tc.verifyError(@() validate_config(cfg), 'localization:config');
        end

        function badFusionMethodRejected(tc)
            cfg = localization_config();
            cfg.fusion_method = 'average';
            tc.verifyError(@() validate_config(cfg), 'localization:config');
        end

        function noModalityEnabledRejected(tc)
            cfg = localization_config();
            cfg.enable_rss = false; cfg.enable_aoa = false; cfg.enable_rtt = false;
            tc.verifyError(@() validate_config(cfg), 'localization:config');
        end

        function layoutsAvailableAndUnknownRejected(tc)
            tc.verifyTrue(ismember('four_corners', anchor_layouts()));
            tc.verifyEqual(size(anchor_layouts('four_corners')), [4 2]);
            tc.verifyError(@() anchor_layouts('nope'), 'localization:config');
        end

        function loadConfigMergesNestedDefaults(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(f.Folder, 'partial.mat');
            cfg = struct('channel', struct('ble', struct('n', 4))); %#ok<NASGU>
            save(file, 'cfg');
            out = load_config(file);
            tc.verifyEqual(out.channel.ble.n, 4);
            tc.verifyEqual(out.channel.wifi.n, 2.2);            % untouched default
            tc.verifyEqual(out.channel.ble.PL0_dB, 50);          % sibling default kept
        end

        function saveThenLoadRoundTrip(tc)
            f = tc.applyFixture(matlab.unittest.fixtures.TemporaryFolderFixture);
            file = fullfile(f.Folder, 'c.mat');
            cfg = localization_config();
            cfg.smooth_win = 7;
            save_config(cfg, file);
            tc.verifyEqual(load_config(file).smooth_win, 7);
        end

        function setCfgParamNestedAndTypoDetected(tc)
            cfg = set_cfg_param(localization_config(), 'noise_scale.aoa', 3);
            tc.verifyEqual(cfg.noise_scale.aoa, 3);
            tc.verifyError(@() set_cfg_param(cfg, 'noise_scale.aao', 1), 'localization:config');
            cfg = set_cfg_param(cfg, 'anchor_layout', 'triangle');
            tc.verifyEqual(size(cfg.anchor_pos), [3 2]);
        end

        function pathLossSmokeTest(tc)
            [out, aoa] = applyPathLossWithAOA(1, 2, 3, 0, 0);
            tc.verifyLessThanOrEqual(abs(out), 1);
            tc.verifyTrue(isfinite(out));
            tc.verifyGreaterThanOrEqual(aoa, 0);
            tc.verifyLessThanOrEqual(aoa, 360);
        end

        function simulateRssDecreasesWithDistance(tc)
            cfg = localization_config();
            cfg.noise_scale.rss = 0;
            r = simulate_rss([0 0; 10 0], [1 0], cfg);
            tc.verifyGreaterThan(r(1), r(2));
        end
    end
end
