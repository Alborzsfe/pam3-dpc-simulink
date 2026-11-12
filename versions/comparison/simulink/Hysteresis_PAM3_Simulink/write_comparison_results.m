function write_comparison_results(result)
cfg = result.config;
file = fullfile(cfg.output_dir, 'summary.csv');
fid = fopen(file, 'w'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, ['Scenario,Block,THD_2to%d_percent,THDN_fullband_percent,' ...
    'Fundamental_RMS_V,Total_RMS_V,DC_V,Mean_power_W,Power_ripple_pp_W,' ...
    'Power_ripple_rms_W,Power_ripple_pp_percent,Power_ripple_rms_percent,' ...
    'Changed_from_clean_percent,Transitions_per_second,Zero_level_percent\n'], ...
    cfg.max_harmonic);
for k = 1:numel(result.rows)
    r = result.rows(k); m = r.metrics;
    values = [m.thd_percent, m.thdn_percent, m.fundamental_rms_v, m.total_rms_v, ...
        m.dc_v, m.mean_power_w, m.power_ripple_pp_w, m.power_ripple_rms_w, ...
        m.power_ripple_pp_percent, m.power_ripple_rms_percent, ...
        r.changed_from_clean_percent, r.transitions_per_second, r.zero_percent];
    fprintf(fid, '%s,%s', r.scenario, r.block);
    fprintf(fid, ',%.12g', values);
    fprintf(fid, '\n');
end
write_input_csv(result);
write_wave_csv(result);
file = fullfile(cfg.output_dir, 'run_info.txt');
fid2 = fopen(file, 'w'); assert(fid2 >= 0);
cleanup2 = onCleanup(@() fclose(fid2)); %#ok<NASGU>
fprintf(fid2, 'Runtime: %s %s\nMATLAB executed: %d\nSimulink executed: %d\n', ...
    result.runtime_product, result.runtime_version, result.matlab_executed, ...
    result.simulink_executed);
if isfield(result, 'source')
    fprintf(fid2, 'Measurement source: %s\n', result.source);
end
fprintf(fid2, 'Input: sine %.12g Hz, peak %.12g normalized units\n', cfg.f0_hz, cfg.amplitude);
fprintf(fid2, 'fs: %.12g Hz; ADC center: %g; ADC gain: %g\n', ...
    cfg.fs_hz, cfg.adc_center, cfg.adc_gain);
fprintf(fid2, 'PAM3 original code unchanged; sample_time scaled for this bench.\n');
fprintf(fid2, 'PAM3 fixed thresholds: 140,95,160,80; DC/adaptation disabled.\n');
fprintf(fid2, 'Hysteresis thresholds: on >= %.12g, off <= %.12g; initial=%g\n', ...
    cfg.hysteresis_on, cfg.hysteresis_off, cfg.hysteresis_initial);
fprintf(fid2, 'Gaussian noise: SNR %.12g dB; seed %g; common to both blocks\n', ...
    result.input.realized_snr_db, cfg.seed);
fprintf(fid2, 'Clipped samples: clean=%g, noisy=%g\n', result.input.clipped_samples);
fprintf(fid2, 'Measurement: warmup %g cycles; measure %g cycles; same window for both\n', ...
    cfg.warmup_cycles, cfg.measure_cycles);
fprintf(fid2, 'THD: coherent exact bins, orders 2..%g; DC excluded\n', cfg.max_harmonic);
fprintf(fid2, 'THD+N: all residual AC below/at sampled Nyquist, DC excluded\n');
fprintf(fid2, 'Assumed voltage: level * %.12g V; resistor %.12g ohm; p=v^2/R\n', ...
    cfg.output_volts_per_level, cfg.resistance_ohm);
fprintf(fid2, 'Ripple RMS=sqrt(mean((p-mean(p)).^2)); ripple pp=max(p)-min(p)\n');
fprintf(fid2, 'Relative ripple = 100*absolute ripple/mean(p)\n');
fprintf(fid2, 'Binary +/-1 levels necessarily have constant resistor power.\n');
fprintf(fid2, 'No converter, grid, DPC, switching table or physical power measurement.\n');
fprintf(fid2, 'No automatic gain equalization, denoising, or parameter optimization.\n');
end

function write_input_csv(result)
fid = fopen(fullfile(result.config.output_dir, 'input_metrics.csv'), 'w');
assert(fid >= 0); cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'Scenario,Measurement_point,THD_percent,THDN_percent,RMS_normalized\n');
names = {'Clean', 'Noisy'}; points = {'Before_ADC', 'After_common_ADC'};
for s = 1:2
    for j = 1:2
        m = result.input_metrics{s, j};
        fprintf(fid, '%s,%s,%.12g,%.12g,%.12g\n', names{s}, points{j}, ...
            m.thd_percent, m.thdn_percent, m.total_rms_v);
    end
end
end

function write_wave_csv(result)
cfg = result.config; data = result.input;
fid = fopen(fullfile(cfg.output_dir, 'waveforms.csv'), 'w');
assert(fid >= 0); cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, ['Time_s,Measure_window,Clean_input,Noise_added,Noisy_input,' ...
    'ADC_clean,ADC_noisy,H_clean,PAM3_clean,H_noisy,PAM3_noisy,' ...
    'P_H_clean_W,P_PAM3_clean_W,P_H_noisy_W,P_PAM3_noisy_W,' ...
    'PAM3_valid_clean,PAM3_valid_noisy\n']);
measured = zeros(numel(data.t), 1); measured(data.measure_index) = 1;
levels = [result.output_levels(:, :, 1), result.output_levels(:, :, 2)];
p = (cfg.output_volts_per_level*levels).^2/cfg.resistance_ohm;
matrix = [data.t, measured, data.clean, data.noise, data.analog(:, 2), ...
    data.adc, levels, p, double(result.pam3_valid)];
format = [repmat('%.12g,', 1, size(matrix, 2)-1), '%.12g\n'];
fprintf(fid, format, matrix');
end
