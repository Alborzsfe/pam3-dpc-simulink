function cfg = quality_config()
% Frequencies below are CONTROL SAMPLING rates, not fixed switching rates.
cfg.control_frequencies_hz = [20e3, 200e3];
cfg.plant_step = 1e-6;
cfg.measurement_step = 5e-6;
cfg.line_frequency = 50;
cfg.stop_time = 0.8;
cfg.fft_start = 0.6;
cfg.fft_cycles = 10;
cfg.plot_cycles = 2;
cfg.max_harmonic = 50; % Report THD(2..50), cutoff=2500 Hz at f1=50 Hz.
cfg.phase_rms_voltage = 50; % Example only: original file does not store e.
cfg.dc_reference = 150;
cfg.steady_drift_limit = 0.02; % Relative change, first/last half of FFT window.
cfg.plot_visible = 'on';
% Default uses the SAME previous fixed/DC-off PAM3 core after ADC mapping.
% Filtered +1/-1 updates the binary DPC state; zero preserves that state.
cfg.proposed_variant = 'patent_filtered_hold';
% Optional NEW adaptation, not the literal patent:
% cfg.proposed_variant = 'ternary_spike_hold';
end
