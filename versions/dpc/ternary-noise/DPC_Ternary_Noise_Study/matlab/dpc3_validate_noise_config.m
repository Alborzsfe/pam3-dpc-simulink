function dpc3_validate_noise_config(c)
dpc3_validate_config(c);
assert(c.noise_sample_time >= c.plant_step && c.noise_sample_time > 0);
assert(abs(c.noise_sample_time/c.plant_step-round(c.noise_sample_time/c.plant_step)) < 1e-8);
assert(all(abs(1./c.control_frequencies_hz/c.noise_sample_time- ...
    round(1./c.control_frequencies_hz/c.noise_sample_time)) < 1e-8));
assert(abs(c.measurement_step/c.noise_sample_time-round(c.measurement_step/c.noise_sample_time)) < 1e-8);
assert(c.disturbance_start > 0 && c.disturbance_start < c.fft_start);
assert(abs(c.disturbance_start/c.noise_sample_time-round(c.disturbance_start/c.noise_sample_time)) < 1e-7);
assert(abs(c.stop_time/c.noise_sample_time-round(c.stop_time/c.noise_sample_time)) < 1e-7);
assert(~isempty(c.noise_seeds) && all(isfinite(c.noise_seeds)) && ...
    all(c.noise_seeds >= 0 & c.noise_seeds < 2^32 & c.noise_seeds == round(c.noise_seeds)));
assert(numel(unique(c.noise_seeds)) == numel(c.noise_seeds));
assert(strcmp(c.study_cases(1).id,'normal'),'DPC3:NormalFirst','Run normal conditions first.');
ids = {c.study_cases.id}; assert(numel(unique(ids)) == numel(ids));
for k = 1:numel(c.study_cases)
    s = c.study_cases(k);
    assert(isvarname(s.id) && numel(s.id) <= 18);
    a = [s.voltage_noise_rms_pu,s.power_noise_rms,s.h5_pu,s.h7_pu,s.ripple_pu];
    assert(numel(s.power_noise_rms) == 2 && all(isfinite(a)) && all(a >= 0));
    assert(isfinite(s.ripple_hz) && s.ripple_hz > 0);
    assert(max(7*c.line_frequency,s.ripple_hz+c.line_frequency) < 0.5/c.measurement_step);
    if k == 1, assert(all(a == 0),'Normal case must have zero disturbance.'); end
end
end
