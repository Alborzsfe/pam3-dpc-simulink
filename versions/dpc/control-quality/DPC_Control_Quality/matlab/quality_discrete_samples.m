function values = quality_discrete_samples(log, sample_time, count, name)
% Exact scheduled samples, without interpolating or searching for a time lag.
% Allow only floating-point clock representation error, never a sample shift.
time = double(log.time(:));
assert(numel(time) == count, 'QUALITY:SampleCount', ...
    '%s: expected %d samples, received %d.', name, count, numel(time));
assert(count >= 1 && isfinite(sample_time) && sample_time > 0);
expected_time = (0:count-1)'*sample_time;
tolerance = min(sample_time/1000, 128*eps(max(1,max(abs(expected_time)))));
assert(all(isfinite(time)) && all(abs(time-expected_time) <= tolerance), ...
    'QUALITY:SampleClock', '%s log does not match the scheduled sample clock.', name);
data = double(log.signals.values);
assert(numel(data) == count && all(isfinite(data(:))), 'QUALITY:ScalarSamples', ...
    '%s: expected one finite scalar value per sample.', name);
values = data(:);
end
