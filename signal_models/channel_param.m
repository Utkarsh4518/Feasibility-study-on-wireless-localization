function v = channel_param(cfg, is_ble, field)
% CHANNEL_PARAM  Per-link vector of a channel parameter.
%
% v = channel_param(cfg, is_ble, 'n')
%
% is_ble - 1xL logical (true for BLE links); picks cfg.channel.ble.<field>
%          for those and cfg.channel.wifi.<field> otherwise.

v = zeros(size(is_ble));
for i = 1:numel(is_ble)
    if is_ble(i)
        v(i) = cfg.channel.ble.(field);
    else
        v(i) = cfg.channel.wifi.(field);
    end
end
end
