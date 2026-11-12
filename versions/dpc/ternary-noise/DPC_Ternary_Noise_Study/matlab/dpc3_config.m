function c = dpc3_config()
c.control_frequencies_hz = [20e3,200e3];
c.plant_step = 1e-6; c.measurement_step = 5e-6;
c.line_frequency = 50; c.phase_rms_voltage = 50; % EXAMPLE: e absent in source.
c.dc_reference = 150; c.stop_time = 0.8;
c.fft_start = 0.6; c.fft_cycles = 10; c.max_harmonic = 50; c.plot_cycles = 2;
c.plot_visible = 'on'; c.steady_drift_limit = 0.02;
c.proposed_variant = 'true_ternary_dynamic_table';
c.release_ratio = 0.5; % Inner release / original outer band, four thresholds.
c.filter_inductance = 15e-3; c.filter_resistance = 0.2;
c.power_weights = [1,1]; c.prediction_guard = true;
c.bypass_signal_relative_tolerance = 1e-9;
c.source_sha256 = 'c637ed60cde46882b00b42aefcaf2d51796233b7814fdf6bbf72d947dcafd9a9';
end
