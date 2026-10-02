%% analyze_localization_resultsv2.m (LEGACY)
% Same algorithms as run_localization_analysis.m; parameters are inlined here.
% For a single config and reusable src, use: run_localization_analysis
% (This version adds RTT-only localization and plots it with RSS / KF / AoA)

%% === 0) Run the Simulink model ===
modelName = 'Localization_Ependorfv2';
disp(['Running simulation for model: ', modelName]);
out = sim(modelName);

%% === 1) Extract Ground Truth & RSS-based Estimated Positions ===
true_x = out.true_x(:);
true_y = out.true_y(:);
est_x  = out.est_x(:);   % RSS/AoA-derived (from Simulink) raw estimate
est_y  = out.est_y(:);

N = min([length(true_x), length(true_y), length(est_x), length(est_y)]);
true_x = true_x(1:N); true_y = true_y(1:N);
est_x  = est_x(1:N);   est_y  = est_y(1:N);

%% === 2) Smooth estimated positions (simple moving average) ===
win = 3;
est_x_smooth = smoothdata(est_x, 'movmean', win);
est_y_smooth = smoothdata(est_y, 'movmean', win);

%% === 3) Kalman Filter on (smoothed) RSS positions ===
% Try to get the real dt from the simulation
if isfield(out, 'tout') && numel(out.tout) > 1
    dt = median(diff(out.tout));
else
    warning('Unable to infer dt from out.tout, defaulting to 1 s.');
    dt = 1;
end

% Measurements (use smoothed positions as measurements)
z = [est_x_smooth(:), est_y_smooth(:)];

% State vector: [x vx y vy]'
A = [1 dt 0  0;
     0  1 0  0;
     0  0 1 dt;
     0  0 0  1];
H = [1 0 0 0;
     0 0 1 0];

% Process noise (white-noise acceleration model)
sigma_a = 0.5; % tune (0.1–1 typical)
q = sigma_a^2;
Q = q * [dt^4/4 dt^3/2 0       0;
         dt^3/2 dt^2   0       0;
         0      0      dt^4/4 dt^3/2;
         0      0      dt^3/2 dt^2];

% Measurement noise (estimated from data). Use a sensible floor to avoid 0.
ex = true_x - est_x_smooth;
ey = true_y - est_y_smooth;
Rx = max(var(ex, 'omitnan'), 1);  % floor at 1 m^2
Ry = max(var(ey, 'omitnan'), 1);
R  = diag([Rx, Ry]);

% Initial state/covariance
x0 = [z(1,1); 0; z(1,2); 0];
P0 = diag([100 10 100 10]);

x = x0; P = P0;
kf_x = zeros(N,1); kf_y = zeros(N,1);
I = eye(4);
chi2_gate = 9.21;   % 95% confidence, 2 DOF

for k = 1:N
    % Predict
    x_pred = A*x;
    P_pred = A*P*A' + Q;

    % Update with Mahalanobis gating
    zk = z(k,:)';
    yk = zk - H*x_pred;
    S  = H*P_pred*H' + R;
    d2 = yk' / S * yk;   % Mahalanobis distance^2

    if d2 <= chi2_gate
        K = P_pred*H'/S;
        x = x_pred + K*yk;
        % Joseph form for numerical stability
        P = (I - K*H)*P_pred*(I - K*H)' + K*R*K';
    else
        % Reject the measurement
        x = x_pred;
        P = P_pred;
    end

    kf_x(k) = x(1);
    kf_y(k) = x(3);
end

% Optional: fused final estimate (usually not required once KF is tuned)
alpha = 0.3;  % trust KF a bit more
final_est_x = alpha * kf_x + (1 - alpha) * est_x_smooth;
final_est_y = alpha * kf_y + (1 - alpha) * est_y_smooth;

%% === 4) Extract AoA signals and triangulate over time (WLS) ===
aoa_names = {'AoA1_RX_wifi','AoA2_RX_wifi','AoA3_RX_wifi'};  % <- EDIT if needed
T = N; % number of timesteps we care about (match to N)
aoa_data = nan(T, numel(aoa_names));

for i = 1:numel(aoa_names)
    sig = getSignalIfExists(out, aoa_names{i});
    if isempty(sig)
        warning('AoA signal %s not found. Filling with NaNs.', aoa_names{i});
        continue;
    end
    data_i = sig.Values.Data(:);
    aoa_data(1:min(T,length(data_i)),i) = data_i(1:min(T,length(data_i)));
end

aoa_rad = deg2rad(aoa_data);   % [T x M]

% Anchor positions (EDIT to match your model)
anchor_pos = [1, 3;
              5, 7;
             10, 11];

est_aoa_x = nan(T,1);
est_aoa_y = nan(T,1);

for t = 1:T
    thetas = aoa_rad(t,:)';
    if any(isnan(thetas))
        continue; % skip if any AoA missing
    end
    [x_est_t, y_est_t] = aoa_localization_wls(anchor_pos, thetas);
    est_aoa_x(t) = x_est_t;
    est_aoa_y(t) = y_est_t;
end

%% === 4b) RTT → distances → (x,y) via trilateration (NEW) ===
rtt_names = {'RTT_WIFI1','RTT_WIFI2','RTT_WIFI3', ...
             'RTT_BLE1','RTT_BLE2','RTT_BLE3'};  % your real names

c = 3e8;                                   % speed of light
rtt_data = nan(T, numel(rtt_names));
haveRTT = true;

for i = 1:numel(rtt_names)
    sig = getSignalIfExists(out, rtt_names{i});
    if isempty(sig)
        warning('RTT signal %s not found. Skipping RTT localization.', rtt_names{i});
        haveRTT = false;
        break;
    end
    di = sig.Values.Data(:);
    rtt_data(1:min(T,numel(di)), i) = di(1:min(T,numel(di)));
end

est_rtt_x = nan(T,1);
est_rtt_y = nan(T,1);

if haveRTT
    rtt_distances = (rtt_data / 2) * c;  % RTT -> one-way distance
    % 6 RTTs = (WiFi 3 + BLE 3) so duplicate anchors:
    anchor_pos_all = [anchor_pos; anchor_pos];
    for t = 1:T
        d = rtt_distances(t,:)';
        if any(isnan(d)), continue; end
        [xr, yr] = trilaterate(anchor_pos_all, d);
        est_rtt_x(t) = xr;
        est_rtt_y(t) = yr;
    end
end

%% === 5) Compute Errors ===
errors_smooth = hypot(true_x - est_x_smooth, true_y - est_y_smooth);
errors_kf     = hypot(true_x - kf_x,        true_y - kf_y);
errors_aoa    = hypot(true_x - est_aoa_x,   true_y - est_aoa_y);
if haveRTT
    errors_rtt = hypot(true_x - est_rtt_x,   true_y - est_rtt_y);
else
    errors_rtt = nan(size(errors_smooth));
end

fprintf('\n--- Localization Accuracy (Smoothed RSS) ---\n');
fprintf('Mean Error      : %.2f m\n', mean(errors_smooth, 'omitnan'));
fprintf('Max Error       : %.2f m\n', max(errors_smooth, [], 'omitnan'));
fprintf('Min Error       : %.2f m\n', min(errors_smooth, [], 'omitnan'));
fprintf('Std Deviation   : %.2f m\n', std(errors_smooth, 'omitnan'));

fprintf('\n--- Localization Accuracy (Kalman Filtered RSS) ---\n');
fprintf('Mean Error      : %.2f m\n', mean(errors_kf, 'omitnan'));
fprintf('Max Error       : %.2f m\n', max(errors_kf, [], 'omitnan'));
fprintf('Min Error       : %.2f m\n', min(errors_kf, [], 'omitnan'));
fprintf('Std Deviation   : %.2f m\n', std(errors_kf, 'omitnan'));

fprintf('\n--- Localization Accuracy (AoA WLS) ---\n');
fprintf('Mean Error      : %.2f m\n', mean(errors_aoa, 'omitnan'));
fprintf('Max Error       : %.2f m\n', max(errors_aoa, [], 'omitnan'));
fprintf('Min Error       : %.2f m\n', min(errors_aoa, [], 'omitnan'));
fprintf('Std Deviation   : %.2f m\n', std(errors_aoa, 'omitnan'));

if haveRTT
    fprintf('\n--- Localization Accuracy (RTT Trilateration) ---\n');
    fprintf('Mean Error      : %.2f m\n', mean(errors_rtt, 'omitnan'));
    fprintf('Max Error       : %.2f m\n', max(errors_rtt, [], 'omitnan'));
    fprintf('Min Error       : %.2f m\n', min(errors_rtt, [], 'omitnan'));
    fprintf('Std Deviation   : %.2f m\n', std(errors_rtt, 'omitnan'));
end

%% === Weighted Fusion (RSS-KF + AoA WLS) ===
w = 0.7;  % (kept as before)
fused_x = w * kf_x + (1 - w) * est_aoa_x;
fused_y = w * kf_y + (1 - w) * est_aoa_y;

errors_fused = hypot(true_x - fused_x, true_y - fused_y);

fprintf('\n--- Localization Accuracy (Weighted Fusion RSS+AoA) ---\n');
fprintf('Mean Error      : %.2f m\n', mean(errors_fused, 'omitnan'));
fprintf('Max Error       : %.2f m\n', max(errors_fused, [], 'omitnan'));
fprintf('Min Error       : %.2f m\n', min(errors_fused, [], 'omitnan'));
fprintf('Std Deviation   : %.2f m\n', std(errors_fused, 'omitnan'));

%% === 6) Plot 1: Estimated vs Ground Truth Path ===
figure('Name','Trajectories');
plot(est_x, est_y, ':k', 'DisplayName', 'Original Estimation'); hold on;
plot(est_x_smooth, est_y_smooth, '--c', 'DisplayName', 'RSS Smoothed');
plot(kf_x, kf_y, '-g', 'LineWidth', 1.2, 'DisplayName', 'RSS Kalman');
if any(~isnan(est_aoa_x))
    plot(est_aoa_x, est_aoa_y, '-r', 'LineWidth', 1.2, 'DisplayName', 'AoA WLS');
end
if haveRTT && any(~isnan(est_rtt_x))
    plot(est_rtt_x, est_rtt_y, '-b', 'LineWidth', 1.2, 'DisplayName', 'RTT Trilateration');
end
plot(true_x, true_y, '--*', 'DisplayName', 'Ground Truth');
if any(~isnan(fused_x))
    plot(fused_x, fused_y, '-m', 'LineWidth', 1.2, 'DisplayName', 'Fusion (RSS + AoA)');
end
legend('Location','best'); xlabel('X (m)'); ylabel('Y (m)');
title('Estimated vs Ground Truth Path');
grid on; axis equal;

%% === 7) Plot 2: Error Comparison ===
figure('Name','Error Comparison');
plot(errors_smooth, '-o', 'DisplayName', 'RSS Smoothed'); hold on;
plot(errors_kf, '-x', 'DisplayName', 'RSS Kalman');
if any(~isnan(errors_aoa))
    plot(errors_aoa, '-s', 'DisplayName', 'AoA WLS');
end
if haveRTT && any(~isnan(errors_rtt))
    plot(errors_rtt, '-d', 'DisplayName', 'RTT Trilateration');
end
if any(~isnan(errors_fused))
    plot(errors_fused, '-^', 'DisplayName', 'Fusion RSS+AoA');
end
xlabel('Timestep'); ylabel('Error (m)');
title('Localization Error Comparison'); legend('Location','best'); grid on;

%% === 8) RSS extraction & plot (safe version) ===
rss_names = {'estRSS1','estRSS2','estRSS3','estmRSS4','estmRSS5','estmRSS6'}; % adjust
rss_signals = cell(1, numel(rss_names));

for i = 1:numel(rss_names)
    sig = getSignalIfExists(out, rss_names{i});
    if ~isempty(sig)
        rss_signals{i} = sig;
    else
        warning('Signal %s not found in logsout.', rss_names{i});
        rss_signals{i} = [];
    end
end

figure('Name','RSSI Measurements');
for i = 1:numel(rss_names)
    subplot(3,2,i);
    if isempty(rss_signals{i})
        text(0.5, 0.5, sprintf('%s not found', rss_names{i}), ...
             'HorizontalAlignment', 'center', 'FontSize', 10);
        axis off; continue;
    end
    sig = rss_signals{i}.Values;
    plot(sig.Time, sig.Data, '-o');
    title(strrep(rss_names{i}, '_', '\_'));
    xlabel('Time (s)'); ylabel('RSS [dBm]');
    grid on;
end
sgtitle('RSSI Measurements from All Anchors');

%% === 9) TX vs RX Signal Comparison (example) ===
try
    rx_signal = getSignalIfExists(out, 'rxSignal1_WiFi');
    if ~isempty(rx_signal)
        rx_time = rx_signal.Values.Time;
        rx_data = rx_signal.Values.Data;
        tx_time = linspace(rx_time(1), rx_time(end), numel(rx_time));
        tx_signal = sin(2*pi*1*tx_time); % example ideal TX

        figure('Name','TX vs RX Signal');
        plot(rx_time, rx_data, 'b-', 'LineWidth', 1.5); hold on;
        plot(rx_time, tx_signal(:), 'r--');
        legend('RX Signal (After Path Loss)', 'TX Signal (Ideal)');
        xlabel('Time (s)'); ylabel('Signal');
        title('TX vs RX Signal'); grid on;
    else
        warning('rxSignal1_WiFi not found, skipping TX vs RX plot.');
    end
catch ME
    warning('Error plotting TX vs RX: %s', ME.message);
end

%% === 10) Anchor-to-Agent Distances ===
anchor_x = [1, 5, 10];  % match anchor_pos
anchor_y = [3, 7, 11];
num_anchors = numel(anchor_x);
anchor_distances = zeros(N, num_anchors);
for i = 1:num_anchors
    dx = true_x - anchor_x(i);
    dy = true_y - anchor_y(i);
    anchor_distances(:,i) = hypot(dx, dy);
end

figure('Name','Anchor Distances');
plot(0:N-1, anchor_distances, '-o', 'LineWidth', 1.2);
legend(arrayfun(@(i) sprintf('Anchor %d', i), 1:num_anchors, 'UniformOutput', false));
xlabel('Timestep'); ylabel('Distance (m)');
title('Anchor-to-Agent Distances'); grid on;

fprintf('\n--- Anchor-to-Agent Distance Stats ---\n');
for i = 1:num_anchors
    d = anchor_distances(:,i);
    fprintf('Anchor %d: Mean = %.2f m, Min = %.2f m, Max = %.2f m\n', ...
        i, mean(d), min(d), max(d));
end

%% ===================== Local helper functions ===================== %%

function sig = getSignalIfExists(out, name)
% Safely fetch a signal from Simulink Dataset logsout
sig = [];
try
    if isprop(out, 'logsout') && ~isempty(out.logsout)
        sig = getElement(out.logsout, name);
    end
catch
    sig = [];
end
end

function [x_est, y_est] = aoa_localization_wls(anchor_pos, aoa_rad, weights)
% Weighted LS for AoA-only localization
% anchor_pos : Nx2 [x_i, y_i]
% aoa_rad    : Nx1 angles (radians) measured from anchor -> agent
% weights    : Nx1 optional, default = 1

Nloc = size(anchor_pos, 1);
A = zeros(Nloc, 2);
b = zeros(Nloc, 1);

for i = 1:Nloc
    xi = anchor_pos(i,1); yi = anchor_pos(i,2);
    theta = aoa_rad(i);
    n = [sin(theta); -cos(theta)];  % line normal
    A(i,:) = n';
    b(i)   = n' * [xi; yi];
end

if nargin < 3 || isempty(weights)
    W = eye(Nloc);
else
    W = diag(weights(:));
end

x_opt = (A' * W * A) \ (A' * W * b);
x_est = x_opt(1);
y_est = x_opt(2);
end

function [x, y] = trilaterate(anchor_pos, d)
% Simple LS trilateration using first anchor as reference
% anchor_pos: Mx2, d: Mx1 distances
M = size(anchor_pos,1);
A = zeros(M-1, 2);
b = zeros(M-1, 1);
x1 = anchor_pos(1,1); y1 = anchor_pos(1,2);
for i = 2:M
    xi = anchor_pos(i,1); yi = anchor_pos(i,2);
    A(i-1,:) = 2 * [xi - x1, yi - y1];
    b(i-1) = (d(1)^2 - d(i)^2) + (xi^2 - x1^2) + (yi^2 - y1^2);
end
sol = (A' * A) \ (A' * b);
x = sol(1); y = sol(2);
end
