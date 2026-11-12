function output = dpc_control_ternary(error_signal, cfg, channel)
% New control-oriented adapter. This is NOT a claim in US11405248B2.
% Two ordinary Schmitt relays on x and -x create a neutral state.
center = (cfg.relay_on(channel) + cfg.relay_off(channel)) / 2;
half_band = (cfg.relay_on(channel) - cfg.relay_off(channel)) / 2;
release = cfg.release_ratio * half_band;
x = double(error_signal(:)) - center;
positive = dpc_relay(x, half_band, release, 1, 0);
negative = dpc_relay(-x, half_band, release, 1, 0);
output = positive - negative;
assert(all(ismember(output, [-1, 0, 1])));
end
