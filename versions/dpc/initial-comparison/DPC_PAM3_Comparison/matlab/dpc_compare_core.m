function result = dpc_compare_core(capture, cfg)
% Same time-stamped errors for all methods. Preserve actual pipeline latency.
dpc_validate_config(cfg);
assert(size(capture.errors, 2) == 2 && size(capture.errors, 1) >= 3);
t = double(capture.time(:)); x = double(capture.errors);
assert(numel(t) == size(x, 1) && all(isfinite(t)) && all(isfinite(x(:))));
assert(all(diff(t) > 0));
assert(max(abs(diff(t)-cfg.sample_time)) < max(1e-12, cfg.sample_time*1e-6), ...
    'DPC:TimeGrid', 'Replay requires a uniform sample-time grid.');
result = struct('cfg', cfg, 'capture', capture, 'channels', {{}});
result.kind = capture.kind;
result.metrics = {};
for channel = 1:2
    c = struct(); c.error = x(:, channel);
    c.binary = dpc_relay(c.error, cfg.relay_on(channel), cfg.relay_off(channel), ...
        cfg.relay_output_on(channel), cfg.relay_output_off(channel));
    c.binary_signed = 2 * (c.binary-cfg.relay_output_off(channel)) / ...
        (cfg.relay_output_on(channel)-cfg.relay_output_off(channel)) - 1;
    c.ternary = dpc_control_ternary(c.error, cfg, channel);
    [c.adc, c.mapping] = dpc_map_adc(c.error, cfg, channel);
    c.patent = pam3_decode(c.adc, dpc_patent_config(cfg));
    n = numel(t); c.raw = c.patent.trace(1:n, 5);
    % Filter output becomes available TWO ticks after its source sample.
    c.filtered_causal = c.patent.trace(1:n, 7);
    c.filtered_valid = c.patent.trace(1:n, 8) ~= 0;
    c.decisions = [c.binary_signed, c.ternary, c.raw, c.filtered_causal];
    c.metrics = dpc_metrics(t, c.error, c.decisions, c.filtered_valid, cfg, channel);
    c.captured_relay_mismatches = NaN;
    if isfield(capture, 'original_binary') && ~isempty(capture.original_binary)
        c.captured_relay_mismatches = sum(c.binary ~= capture.original_binary(:, channel));
    end
    output_ticks = find(c.patent.trace(:, 1) ~= 0)-1;
    c.symbol_emission_time = t(1) + output_ticks * cfg.sample_time;
    c.symbol_source_time = t(1) + c.patent.points * cfg.sample_time;
    c.symbol_latency_s = c.symbol_emission_time - c.symbol_source_time;
    result.channels{channel} = c;
    result.metrics = [result.metrics, c.metrics]; %#ok<AGROW>
end
result.same_input_assertion = true;
result.closed_loop_modified = false;
result.simulink_replay_executed = false;
end
