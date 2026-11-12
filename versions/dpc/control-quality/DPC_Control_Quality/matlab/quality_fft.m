function r = quality_fft(x, sample_time, fundamental, max_harmonic)
% Coherent FFT: exact complete cycles, no duplicated endpoint or window taper.
% Returns percent harmonic-only THD(2..max_harmonic), excluding DC.
x = double(x(:)); n = numel(x);
assert(n >= 4 && all(isfinite(x)) && sample_time > 0 && fundamental > 0);
cycles = n*sample_time*fundamental;
assert(abs(cycles-round(cycles)) < 1e-7, 'QUALITY:FFTWindow', ...
    'FFT requires an integer number of fundamental cycles.');
cycles = round(cycles);
assert(cycles >= 1 && max_harmonic*cycles < n/2);
spectrum = fft(x)/n;
orders = (1:max_harmonic)'; bins = orders*cycles+1;
harmonic_rms = sqrt(2)*abs(spectrum(bins));
r = struct('orders', orders, 'harmonic_rms', harmonic_rms, ...
    'fundamental_rms', harmonic_rms(1), 'dc', mean(x), ...
    'signal_rms', sqrt(mean(x.^2)), 'fundamental_hz', fundamental, ...
    'max_harmonic', max_harmonic, 'cutoff_hz', max_harmonic*fundamental, ...
    'cycles', cycles, 'samples', n, 'thd_percent', NaN, ...
    'harmonic_percent', NaN(size(orders)), 'residual_rms', NaN);
if harmonic_rms(1) > max(1e-12, 1e-9*r.signal_rms)
    r.thd_percent = 100*sqrt(sum(harmonic_rms(2:end).^2))/harmonic_rms(1);
    r.harmonic_percent = 100*harmonic_rms/harmonic_rms(1);
end
residual_power = mean((x-mean(x)).^2)-sum(harmonic_rms.^2);
r.residual_rms = sqrt(max(0, residual_power));
end
