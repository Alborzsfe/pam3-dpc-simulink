function stats = dpc_latency(t, x, decision, valid, cfg, channel)
% Diagnostic response to sustained outer-band episodes; no SER ground truth.
t = double(t(:)); x = double(x(:)); decision = double(decision(:));
urgent = double(x > cfg.relay_on(channel)) - double(x < cfg.relay_off(channel));
starts = find(urgent ~= 0 & [true; urgent(2:end) ~= urgent(1:end-1)]);
delay = []; missed = 0; events = 0;
for j = 1:numel(starts)
    a = starts(j);
    if ~valid(a), continue; end
    b = a;
    while b < numel(x) && urgent(b+1) == urgent(a)
        b = b + 1;
    end
    events = events + 1;
    match = find(valid(a:b) & decision(a:b) == urgent(a), 1, 'first');
    if isempty(match)
        missed = missed + 1;
    else
        delay(end+1, 1) = t(a+match-1) - t(a); %#ok<AGROW>
    end
end
stats = struct('outer_band_episodes', events, 'episodes_without_response', missed, ...
    'response_latency_mean_s', NaN, 'response_latency_max_s', NaN);
if ~isempty(delay)
    stats.response_latency_mean_s = mean(delay);
    stats.response_latency_max_s = max(delay);
end
end
