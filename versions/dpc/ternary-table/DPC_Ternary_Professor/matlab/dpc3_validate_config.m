function dpc3_validate_config(c)
assert(all(isfinite(c.control_frequencies_hz)) && all(c.control_frequencies_hz > 0));
assert(c.plant_step > 0 && c.measurement_step >= c.plant_step);
assert(all(abs(1./c.control_frequencies_hz/c.plant_step- ...
    round(1./c.control_frequencies_hz/c.plant_step)) < 1e-8));
assert(abs(c.measurement_step/c.plant_step-round(c.measurement_step/c.plant_step)) < 1e-8);
assert(isfinite(c.phase_rms_voltage) && c.phase_rms_voltage > 0);
assert(c.filter_inductance > 0 && c.filter_resistance >= 0 && c.line_frequency > 0);
assert(c.release_ratio > 0 && c.release_ratio <= 1);
assert(numel(c.power_weights) == 2 && all(c.power_weights > 0));
assert(c.fft_cycles >= 1 && c.fft_cycles == round(c.fft_cycles));
assert(c.max_harmonic >= 2 && c.max_harmonic == round(c.max_harmonic));
assert(c.max_harmonic*c.line_frequency < 0.5/c.measurement_step);
assert(c.fft_start >= 0 && c.fft_start+c.fft_cycles/c.line_frequency <= c.stop_time+1e-12);
assert(abs(1/(c.line_frequency*c.measurement_step)-round(1/(c.line_frequency*c.measurement_step))) < 1e-7);
assert(c.plot_cycles > 0 && c.plot_cycles <= c.fft_cycles);
assert(any(strcmp(c.plot_visible,{'on','off'})));
end
