function dpc_write_reports(result, folder)
% Plain export with explicit provenance and no claim about closed-loop benefit.
if ~exist(folder, 'dir'), mkdir(folder); end
metrics_path = fullfile(folder, 'decision_metrics.csv');
fid = fopen(metrics_path, 'w'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, ['channel,method,samples,decision_changes,decision_changes_per_second,' ...
    'neutral_fraction,outer_band_sign_mismatch_fraction,inner_band_active_fraction,' ...
    'outer_band_episodes,episodes_without_response,response_latency_mean_s,response_latency_max_s\n']);
for k = 1:numel(result.metrics)
    r = result.metrics{k};
    fprintf(fid, '%s,%s,%d,%d,%.12g,%.12g,%.12g,%.12g,%d,%d,%.12g,%.12g\n', ...
        r.channel, r.method, r.samples, r.decision_changes, ...
        r.decision_changes_per_second, r.neutral_fraction, ...
        r.outer_band_sign_mismatch_fraction, r.inner_band_active_fraction, ...
        r.outer_band_episodes, r.episodes_without_response, ...
        r.response_latency_mean_s, r.response_latency_max_s);
end
clear cleanup
t = result.capture.time;
for channel = 1:2
    c = result.channels{channel}; label = result.cfg.channels{channel};
    observed = NaN(size(t));
    if isfield(result.capture, 'original_binary')
        observed = result.capture.original_binary(:, channel);
    end
    matrix = [t, c.error, observed, c.binary, c.binary_signed, c.ternary, ...
        c.adc, c.raw, c.filtered_causal, double(c.filtered_valid)];
    write_matrix(fullfile(folder, ['trace_' label '.csv']), ...
        ['time_s,error,observed_converter_relay,binary_replay,binary_replay_signed,' ...
         'control_ternary,adc_code,patent_raw,patent_filtered_causal,filtered_valid'], matrix);
    matrix = [c.symbol_source_time, c.symbol_emission_time, c.symbol_latency_s, ...
        c.patent.points, c.patent.symbols];
    write_matrix(fullfile(folder, ['patent_symbols_' label '.csv']), ...
        'source_time_s,emission_time_s,latency_s,zero_based_source_index,symbol', matrix);
end
fid = fopen(fullfile(folder, 'RUN_REPORT.md'), 'w'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Identical-input DPC / PAM3 comparison\n\n');
fprintf(fid, '- Input provenance: **%s**.\n', result.kind);
fprintf(fid, '- Same error samples supplied to all comparison routes: %d.\n', result.same_input_assertion);
fprintf(fid, '- Actual comparison Simulink replay executed: %d.\n', result.simulink_replay_executed);
fprintf(fid, '- Closed-loop gate table modified: %d.\n', result.closed_loop_modified);
fprintf(fid, '- Samples per channel: %d; sample time: %.12g s.\n', numel(t), result.cfg.sample_time);
fprintf(fid, '- Patent mode: %d (0 fixed; 1 Q8 engineering update). DC correction bypassed.\n', result.cfg.patent_mode);
fprintf(fid, '- Neutral release/activation ratio: %.6g.\n\n', result.cfg.release_ratio);
if isfield(result.capture, 'single_timestamp_signals_held') && ...
        ~isempty(result.capture.single_timestamp_signals_held)
    fprintf(fid, 'Single-timestamp signals held after initialization: %s.\n\n', ...
        strjoin(result.capture.single_timestamp_signals_held, ', '));
end
if isfield(result.capture, 'measurement_only_cleanup')
    for k = 1:numel(result.capture.measurement_only_cleanup)
        fprintf(fid, 'Measurement-only cleanup in recording copy: %s\n\n', ...
            result.capture.measurement_only_cleanup{k});
    end
end
if isfield(result.capture, 'parameters')
    p = result.capture.parameters;
    fprintf(fid, 'Converter parameters: `Ts=%.12g s`, `e=%.12g V RMS`.\n\n', p.Ts, p.e);
    for k = 1:numel(result.capture.parameter_assumptions)
        fprintf(fid, '**Benchmark assumption:** %s\n\n', result.capture.parameter_assumptions{k});
    end
end
fprintf(fid, '| Channel | Method | Decision changes | Neutral %% | Outer-band sign mismatch %% | Mean response us | Missed episodes |\n');
fprintf(fid, '|---|---|---:|---:|---:|---:|---:|\n');
for k = 1:numel(result.metrics)
    r = result.metrics{k};
    fprintf(fid, '| %s | %s | %d | %.3f | %.3f | %.3f | %d |\n', r.channel, r.method, ...
        r.decision_changes, 100*r.neutral_fraction, 100*r.outer_band_sign_mismatch_fraction, ...
        1e6*r.response_latency_mean_s, r.episodes_without_response);
end
fprintf(fid, '\n## Calibration and original capture diagnostics\n\n');
for channel = 1:2
    c = result.channels{channel}; m = c.mapping;
    fprintf(fid, ['%s: ADC=clip(round(%.12g + %.12g*error),0,255). ' ...
        'Clipped samples: %.4f%%. Quantization half-LSB: %.12g model error units.\n\n'], ...
        result.cfg.channels{channel}, m.offset_codes, m.gain_codes_per_error_unit, ...
        100*m.clipping_fraction, m.half_lsb_in_error_units);
    fprintf(fid, 'Initial thresholds [plus, minus, zero-plus, zero-minus] in error units: [%.6g %.6g %.6g %.6g].\n\n', ...
        m.thresholds_in_error_units);
    if isfinite(c.captured_relay_mismatches)
        fprintf(fid, ['Observed converter relay versus sampled replay mismatches: %d. ' ...
            'A nonzero count can indicate intervening continuous-time events or resampling; ' ...
            'it prevents claiming exact reproduction of the original continuous-time relay trajectory.\n\n'], ...
            c.captured_relay_mismatches);
    end
end
fprintf(fid, ['## Interpretation\n\nDecision changes are detector output transitions, not measured semiconductor switching. ' ...
    'The binary output is mapped from OFF/ON to -1/+1 only for sign diagnostics; native 0/1 is exported too.\n\n' ...
    'The causal patent filter has 2-sample latency. Symbol outputs have 20-sample latency ' ...
    'and are sparse; they are not treated as a sample-rate converter control output.\n\n' ...
    'Outer-band sign mismatch and response latency are rule-based diagnostics, not communication SER. ' ...
    'A neutral state or fewer decisions alone does not establish better P/Q tracking, ripple, THD, or efficiency. ' ...
    'Those require a redesigned switching table and separate closed-loop simulations.\n']);
clear cleanup
end

function write_matrix(path, header, matrix)
fid = fopen(path, 'w'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', header);
if ~isempty(matrix)
    format = [repmat('%.12g,', 1, size(matrix, 2)-1), '%.12g\n'];
    fprintf(fid, format, matrix');
end
end
