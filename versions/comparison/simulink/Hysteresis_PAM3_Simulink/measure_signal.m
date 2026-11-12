function m = measure_signal(v, fs, f0, max_harmonic, resistance)
% Coherent Fourier-series estimate on an integer number of f0 cycles.
% THD uses only the selected exact harmonic bins. THD+N uses all AC residual.
v = double(v(:));
n = numel(v);
assert(n > 2 && all(isfinite(v)) && resistance > 0);
base_bin = round(n*f0/fs);
assert(base_bin >= 1 && abs(n*f0/fs-base_bin) < 1e-9, ...
    'Compare:Window', 'Measurement must contain an integer number of cycles.');
assert(max_harmonic == floor(max_harmonic) && max_harmonic >= 2 && ...
    max_harmonic*base_bin < n/2);
ac = v-mean(v);
X = fft(ac)/n;
bins = (1:max_harmonic)'*base_bin+1;
harmonic_rms = sqrt(2)*abs(X(bins));
fundamental_rms = harmonic_rms(1);
ac_rms = sqrt(mean(ac.^2));
if fundamental_rms <= 1e-12*max(1, sqrt(mean(v.^2)))
    thd_percent = NaN;
    thdn_percent = NaN;
else
    thd_percent = 100*sqrt(sum(harmonic_rms(2:end).^2))/fundamental_rms;
    residual_power = max(0, ac_rms^2-fundamental_rms^2);
    thdn_percent = 100*sqrt(residual_power)/fundamental_rms;
end
p = v.^2/resistance;
p_mean = mean(p);
ripple_rms = sqrt(mean((p-p_mean).^2));
ripple_pp = max(p)-min(p);
if p_mean > 1e-12
    ripple_rms_pct = 100*ripple_rms/p_mean;
    ripple_pp_pct = 100*ripple_pp/p_mean;
else
    ripple_rms_pct = NaN;
    ripple_pp_pct = NaN;
end
m = struct('thd_percent', thd_percent, 'thdn_percent', thdn_percent, ...
    'fundamental_rms_v', fundamental_rms, 'total_rms_v', sqrt(mean(v.^2)), ...
    'dc_v', mean(v), 'mean_power_w', p_mean, 'power_ripple_pp_w', ripple_pp, ...
    'power_ripple_rms_w', ripple_rms, 'power_ripple_pp_percent', ripple_pp_pct, ...
    'power_ripple_rms_percent', ripple_rms_pct, 'harmonic_rms', harmonic_rms, ...
    'harmonic_hz', (1:max_harmonic)'*f0);
end
