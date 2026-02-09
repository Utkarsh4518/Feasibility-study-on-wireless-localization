function plot_results(out, cfg, results)
% PLOT_RESULTS  Generate evaluation figures for enabled modalities only.
%
% plot_results(out, cfg, results)
%
% Inputs:
%   out    - Simulink simulation output
%   cfg    - Config struct (enable_rss, enable_aoa, enable_rtt, anchor_*, etc.)
%   results - Struct with estimates and errors (see run_experiment)

R = results;
N = length(R.true_x);
haveRTT = R.haveRTT;
en_rss = cfg.enable_rss;
en_aoa = cfg.enable_aoa;
en_rtt = cfg.enable_rtt;

%% Trajectories (only plot enabled estimates)
figure('Name','Trajectories');
plot(R.est_x_raw, R.est_y_raw, ':k', 'DisplayName', 'Raw RSS Est.'); hold on;
if en_rss
    plot(R.est_x_smooth, R.est_y_smooth, '--c', 'DisplayName', 'RSS Smoothed');
    plot(R.kf_x, R.kf_y, '-g', 'LineWidth', 1.2, 'DisplayName', 'RSS Kalman');
end
if en_aoa && any(~isnan(R.est_aoa_x))
    plot(R.est_aoa_x, R.est_aoa_y, '-r', 'LineWidth', 1.2, 'DisplayName', 'AoA WLS');
end
if en_rtt && haveRTT && any(~isnan(R.est_rtt_x))
    plot(R.est_rtt_x, R.est_rtt_y, '-b', 'LineWidth', 1.2, 'DisplayName', 'RTT Trilateration');
end
plot(R.true_x, R.true_y, '--*', 'DisplayName', 'Ground Truth');
if any(~isnan(R.fused_x))
    plot(R.fused_x, R.fused_y, '-m', 'LineWidth', 1.2, 'DisplayName', 'Fusion');
end
legend('Location','best'); xlabel('X (m)'); ylabel('Y (m)');
title('Estimated vs Ground Truth Path (simulation)');
grid on; axis equal;

%% Error comparison (only enabled)
figure('Name','Error Comparison');
hold on;
if en_rss
    plot(R.errors_smooth, '-o', 'DisplayName', 'RSS Smoothed');
    plot(R.errors_kf, '-x', 'DisplayName', 'RSS Kalman');
end
if en_aoa && any(~isnan(R.errors_aoa))
    plot(R.errors_aoa, '-s', 'DisplayName', 'AoA WLS');
end
if en_rtt && haveRTT && any(~isnan(R.errors_rtt))
    plot(R.errors_rtt, '-d', 'DisplayName', 'RTT Trilateration');
end
if any(~isnan(R.errors_fused))
    plot(R.errors_fused, '-^', 'DisplayName', 'Fusion');
end
xlabel('Timestep'); ylabel('Error (m)');
title('Localization Error (simulation)'); legend('Location','best'); grid on;

%% RSSI from anchors (only if RSS enabled)
if en_rss
    rss_names = cfg.rss_names;
    rss_signals = cell(1, numel(rss_names));
    for i = 1:numel(rss_names)
        sig = getSignalIfExists(out, rss_names{i});
        if ~isempty(sig), rss_signals{i} = sig; else rss_signals{i} = []; end
    end
    figure('Name','RSSI Measurements');
    for i = 1:numel(rss_names)
        subplot(3,2,i);
        if isempty(rss_signals{i})
            text(0.5, 0.5, sprintf('%s not found', rss_names{i}), 'HorizontalAlignment', 'center', 'FontSize', 10);
            axis off; continue;
        end
        s = rss_signals{i}.Values;
        plot(s.Time, s.Data, '-o');
        title(strrep(rss_names{i}, '_', '\_'));
        xlabel('Time (s)'); ylabel('RSS [dBm]');
        grid on;
    end
    sgtitle('RSSI Measurements from All Anchors (simulation)');
end

%% TX vs RX
try
    rx_signal = getSignalIfExists(out, cfg.rx_signal_name);
    if ~isempty(rx_signal)
        rx_time = rx_signal.Values.Time;
        rx_data = rx_signal.Values.Data;
        tx_signal = sin(2*pi*1*linspace(rx_time(1), rx_time(end), numel(rx_time)));
        figure('Name','TX vs RX Signal');
        plot(rx_time, rx_data, 'b-', 'LineWidth', 1.5); hold on;
        plot(rx_time, tx_signal(:), 'r--');
        legend('RX Signal (After Path Loss)', 'TX Signal (Ideal)');
        xlabel('Time (s)'); ylabel('Signal');
        title('TX vs RX Signal (simulation)'); grid on;
    end
catch ME
    warning('TX vs RX plot skipped: %s', ME.message);
end

%% Anchor-to-agent distances
anchor_x = cfg.anchor_x;
anchor_y = cfg.anchor_y;
num_anchors = numel(anchor_x);
anchor_distances = zeros(N, num_anchors);
for i = 1:num_anchors
    anchor_distances(:,i) = hypot(R.true_x - anchor_x(i), R.true_y - anchor_y(i));
end

figure('Name','Anchor Distances');
plot(0:N-1, anchor_distances, '-o', 'LineWidth', 1.2);
legend(arrayfun(@(i) sprintf('Anchor %d', i), 1:num_anchors, 'UniformOutput', false));
xlabel('Timestep'); ylabel('Distance (m)');
title('Anchor-to-Agent Distances (simulation)'); grid on;

fprintf('\n--- Anchor-to-Agent Distance Stats ---\n');
for i = 1:num_anchors
    d = anchor_distances(:,i);
    fprintf('Anchor %d: Mean = %.2f m, Min = %.2f m, Max = %.2f m\n', i, mean(d), min(d), max(d));
end
end
