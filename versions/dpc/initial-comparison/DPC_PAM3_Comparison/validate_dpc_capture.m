function report = validate_dpc_capture()
% Causal resampling test including duplicate time stamps and no future data.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'));
cfg = dpc_config(); cfg.sample_time = 1;
times = [0; .4; 1.4; 1.4; 2.4; 3.4; 4];
values = [0; 10; 20; 21; 30; 40; 50];
raw = struct();
raw.ep = make_log(times, values);
raw.eq = make_log(times, -values);
raw.dp = make_log(times, double(values > 0));
raw.dq = make_log(times, double(values < 0));
capture = dpc_uniform_capture(raw, cfg);
assert(isequal(capture.time, (0:4)'));
assert(isequal(capture.errors(:, 1), [0;10;21;30;50]));
assert(isequal(capture.errors(:, 2), -[0;10;21;30;50]));
assert(abs(capture.maximum_sample_age_s.ep-.6) < 1e-12);
assert(isequal(capture.original_binary(:, 1), [0;1;1;1;1]));
% Simulink can log a constant qref only at t=0. Preserve the full duration.
raw.qref = make_log(0, 0);
raw.gates = make_log(0, [1, 0, 1, 0, 1, 0]);
raw.dq = make_log(0, 0);
capture = dpc_uniform_capture(raw, cfg);
assert(isequal(capture.time, (0:4)'));
assert(isequal(capture.signals.qref, zeros(5, 1)));
assert(isequal(capture.signals.gates, repmat([1,0,1,0,1,0], 5, 1)));
assert(isequal(capture.original_binary(:, 2), zeros(5, 1)));
assert(all(ismember({'qref', 'gates', 'dq'}, capture.single_timestamp_signals_held)));
% A singleton first recorded later cannot be used before its timestamp.
raw.qref = make_log(1.4, 7);
capture = dpc_uniform_capture(raw, cfg);
assert(isequal(capture.time, (2:4)'));
assert(isequal(capture.signals.qref, 7*ones(3, 1)));
% Do not invent a duration when every log has just one timestamp.
one = struct('ep', make_log(0,0), 'eq', make_log(0,0), ...
    'dp', make_log(0,0), 'dq', make_log(0,0));
failed = false;
try
    dpc_uniform_capture(one, cfg);
catch exception
    failed = strcmp(exception.identifier, 'DPC:CaptureDuration');
end
assert(failed);
report = struct('passed', true, 'duplicate_timestamps_keep_last', true, ...
    'zero_order_hold_is_causal', true, 'single_timestamp_scalar_and_vector_supported', true, ...
    'late_single_timestamp_is_causal', true, 'missing_duration_rejected', true, ...
    'converter_executed', false, 'runtime', version);
save(fullfile(root, 'validation', 'capture_validation.mat'), 'report', '-v7');
fprintf('PASS capture preparation: causal hold, duplicate timestamps, scalar/vector single-timestamp logs.\n');
end

function log = make_log(time, values)
log = struct('time', time, 'signals', struct('values', values, 'dimensions', size(values, 2)));
end
