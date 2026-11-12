function c = dpc3_noise_config()
c = dpc3_config();
c.study_revision = 'DPC3_NOISE_R1_2026_10_15';
c.disturbance_start = 0.3;
c.noise_sample_time = 5e-6; % SAME 200-kHz sensor-noise record at both control rates.
c.noise_seeds = 104729; % Pilot: one realization. Add seeds for repeated trials.
c.study_cases = dpc3_noise_cases();
c.plot_visible = 'off';
c.resume_completed = true;
end
