function cfg = comparison_config()
% Only this file needs editing for the simple experiment.
cfg.f0_hz = 50;
cfg.fs_hz = 24000;          % 480 samples/cycle = 40 original 12-sample ticks.
cfg.amplitude = 1;          % Clean sine peak, normalized input units.
cfg.warmup_cycles = 5;
cfg.measure_cycles = 20;
cfg.tail_cycles = 1;
cfg.noise_snr_db = 20;      % Same Gaussian-noise realization for both blocks.
cfg.seed = 1729;
cfg.max_harmonic = 40;      % THD: orders 2..40, i.e. 100..2000 Hz by default.
cfg.adc_center = 127;
cfg.adc_gain = 67;
cfg.hysteresis_on = 0.20;   % >= turns on; thresholds in normalized ADC units.
cfg.hysteresis_off = -0.20; % <= turns off; between them, hold previous output.
cfg.hysteresis_initial = -1;
cfg.output_volts_per_level = 1; % Explicit hypothetical voltage conversion.
cfg.resistance_ohm = 1;         % Hypothetical resistor; p = v^2/R.
cfg.make_plots = true;
cfg.show_figures = true;
cfg.save_results = true;
cfg.output_dir = fullfile(fileparts(mfilename('fullpath')), 'results');
end
