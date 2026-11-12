function rows = dpc_metrics(t, x, decisions, valid, cfg, channel)
% Count decision transitions, not semiconductor switching events.
t = double(t(:)); x = double(x(:)); valid = logical(valid(:));
valid = valid & t >= cfg.analysis_start;
assert(any(valid), 'DPC:Window', 'Analysis window contains no samples.');
names = {'binary_replay', 'control_ternary', 'patent_raw', 'patent_filtered_causal'};
center = (cfg.relay_on(channel) + cfg.relay_off(channel)) / 2;
h = (cfg.relay_on(channel) - cfg.relay_off(channel)) / 2;
urgent = double(x > cfg.relay_on(channel)) - double(x < cfg.relay_off(channel));
inner = abs(x-center) < cfg.release_ratio*h;
elapsed = max(t(valid)) - min(t(valid));
rows = cell(1, numel(names));
for k = 1:numel(names)
    y = decisions(:, k);
    pairs = valid(1:end-1) & valid(2:end);
    changes = sum(diff(y) ~= 0 & pairs);
    row = struct('channel', cfg.channels{channel}, 'method', names{k}, ...
        'samples', sum(valid), 'decision_changes', changes, ...
        'decision_changes_per_second', changes / max(elapsed, eps), ...
        'neutral_fraction', mean(y(valid) == 0), ...
        'outer_band_sign_mismatch_fraction', NaN, ...
        'inner_band_active_fraction', NaN);
    outer_mask = valid & urgent ~= 0;
    if any(outer_mask)
        row.outer_band_sign_mismatch_fraction = mean(y(outer_mask) ~= urgent(outer_mask));
    end
    inner_mask = valid & inner;
    if any(inner_mask)
        row.inner_band_active_fraction = mean(y(inner_mask) ~= 0);
    end
    latency = dpc_latency(t, x, y, valid, cfg, channel);
    for f = fieldnames(latency)'
        row.(f{1}) = latency.(f{1});
    end
    rows{k} = row;
end
end
