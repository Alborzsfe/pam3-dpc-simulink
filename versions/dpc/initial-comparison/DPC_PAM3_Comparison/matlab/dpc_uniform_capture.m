function capture = dpc_uniform_capture(raw, cfg)
% Causal ZOH resampling, no future interpolation. Native logs are saved too.
names = fieldnames(raw);
logs = struct(); first = -inf; last = inf;
for k = 1:numel(names)
    name = names{k}; r = raw.(name);
    assert(isstruct(r) && isfield(r, 'time') && isfield(r, 'signals'), ...
        'DPC:LogFormat', 'Invalid log format for signal %s.', name);
    time = double(r.time(:));
    assert(~isempty(time), 'DPC:EmptyLog', 'No recorded samples for signal %s.', name);
    values = reshape(double(r.signals.values), numel(time), []);
    assert(all(isfinite(time)) && all(isfinite(values(:))), ...
        'DPC:NonfiniteLog', 'Nonfinite recorded data in signal %s.', name);
    [time, indices] = unique(time, 'last');
    values = values(indices, :);
    logs.(name) = struct('time', time, 'values', values);
    first = max(first, time(1));
    % Constant-rate signals (e.g. qref=0) can be logged only once.
    % They remain available after initialization and do not end the capture.
    if numel(time) >= 2
        last = min(last, time(end));
    end
end
assert(isfinite(last), 'DPC:CaptureDuration', ...
    'At least one multi-timestamp log is needed to establish the capture duration.');
ticks = (ceil(first/cfg.sample_time-1e-8):floor(last/cfg.sample_time+1e-8))';
t = ticks*cfg.sample_time;
assert(numel(t) >= 3, 'DPC:Capture', 'Converter log is too short.');
% Eliminate tiny endpoint roundoff, keeping all input timestamps in range.
t = t(t >= first-1e-12 & t <= last+1e-12);
samples = struct(); age = struct(); held = {};
for k = 1:numel(names)
    name = names{k}; r = logs.(name);
    if numel(r.time) == 1
        samples.(name) = repmat(r.values, numel(t), 1);
        age.(name) = max(t-r.time(1));
        held{end+1} = name; %#ok<AGROW>
    else
        query = min(r.time(end), max(r.time(1), t));
        samples.(name) = interp1(r.time, r.values, query, 'previous');
        prior_time = interp1(r.time, r.time, query, 'previous');
        age.(name) = max(query-prior_time);
    end
end
capture = struct('time', t, 'sample_time', cfg.sample_time, ...
    'errors', [samples.ep, samples.eq], ...
    'original_binary', [samples.dp, samples.dq], 'signals', samples, ...
    'maximum_sample_age_s', age, 'resampling', 'causal zero-order hold', ...
    'single_timestamp_signals_held', {held});
end
