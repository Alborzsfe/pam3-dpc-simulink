function d = pam3_decode(adc, cfg)
% Offline convenience wrapper around the exact streaming transition.
adc = double(adc(:)); n = numel(adc);
pam3_validate_config(cfg);
s = pam3_initial_state(cfg);
trace = zeros(n + 20, 18);
for k = 1:n
    [s, y] = pam3_step(s, adc(k), 1, cfg);
    trace(k, :) = y';
end
for k = 1:20
    [s, y] = pam3_step(s, 0, 2, cfg);
    trace(n + k, :) = y';
end
d = pam3_trace_decode(trace);
d.final_state = s;
end
