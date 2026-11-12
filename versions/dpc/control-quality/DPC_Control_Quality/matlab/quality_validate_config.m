function quality_validate_config(cfg)
assert(all(isfinite(cfg.control_frequencies_hz)) && all(cfg.control_frequencies_hz > 0));
assert(cfg.plant_step > 0 && cfg.measurement_step >= cfg.plant_step);
assert(abs(cfg.measurement_step/cfg.plant_step-round(cfg.measurement_step/cfg.plant_step)) < 1e-8);
for f = cfg.control_frequencies_hz
    ratio = (1/f)/cfg.plant_step;
    assert(abs(ratio-round(ratio)) < 1e-8, 'QUALITY:Rate', ...
        'Controller periods must be integer multiples of the plant step.');
end
assert(cfg.line_frequency > 0 && cfg.phase_rms_voltage > 0);
assert(isfinite(cfg.phase_rms_voltage) && isfinite(cfg.dc_reference) && cfg.dc_reference > 0);
assert(cfg.stop_time > 0 && cfg.plot_cycles > 0 && cfg.plot_cycles <= cfg.fft_cycles);
assert(abs(cfg.stop_time/cfg.measurement_step-round(cfg.stop_time/cfg.measurement_step)) < 1e-7);
assert(abs(cfg.fft_start/cfg.measurement_step-round(cfg.fft_start/cfg.measurement_step)) < 1e-7);
assert(cfg.fft_cycles >= 1 && cfg.fft_cycles == floor(cfg.fft_cycles));
assert(cfg.max_harmonic >= 2 && cfg.max_harmonic == floor(cfg.max_harmonic));
assert(cfg.max_harmonic*cfg.line_frequency < 0.5/cfg.measurement_step);
assert(abs(1/(cfg.line_frequency*cfg.measurement_step)- ...
    round(1/(cfg.line_frequency*cfg.measurement_step))) < 1e-7);
assert(cfg.fft_start >= 0 && cfg.fft_start+cfg.fft_cycles/cfg.line_frequency <= cfg.stop_time+1e-12);
assert(any(strcmp(cfg.proposed_variant, {'patent_filtered_hold', 'ternary_spike_hold'})));
assert(any(strcmp(cfg.plot_visible, {'on', 'off'})));
end
