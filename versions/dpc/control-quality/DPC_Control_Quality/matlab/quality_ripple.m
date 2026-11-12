function r = quality_ripple(x)
x = double(x(:)); assert(~isempty(x) && all(isfinite(x)));
r.mean = mean(x);
r.peak_to_peak = max(x)-min(x);
r.ripple_rms = sqrt(mean((x-r.mean).^2));
r.peak_to_peak_percent_of_abs_mean = NaN;
if abs(r.mean) > 1e-9
    r.peak_to_peak_percent_of_abs_mean = 100*r.peak_to_peak/abs(r.mean);
end
end
