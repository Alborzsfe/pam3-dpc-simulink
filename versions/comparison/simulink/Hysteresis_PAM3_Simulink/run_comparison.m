function result = run_comparison(cfg)
% Four direct block tests: clean/noisy x hysteresis/original PAM3.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'PAM3_original'));
if nargin < 1
    cfg = comparison_config();
end
assert(cfg.resistance_ohm > 0 && cfg.output_volts_per_level > 0);
data = make_test_input(cfg);
pcfg = pam3_config();
pcfg.sample_time = 1/cfg.fs_hz; % Time scaling only; original logic unchanged.
scenarios = {'Clean', 'Noisy'};
blocks = {'Hysteresis', 'PAM3'};
% MATLAB requires identical outer fields for every structure-array element.
% Preallocate all four rows from one explicit schema (not a fieldless struct).
row_template = struct('scenario', '', 'block', '', 'metrics', [], ...
    'changed_from_clean_percent', NaN, 'transitions_per_second', NaN, ...
    'zero_percent', NaN);
rows = repmat(row_template, 1, numel(scenarios)*numel(blocks));
result = struct('config', cfg, 'pam3_config', pcfg, 'input', data);
result.output_levels = zeros(numel(data.t), 2, 2);
result.pam3 = cell(1, 2);
result.pam3_valid = false(numel(data.t), 2);
for s = 1:2
    same_adc = data.adc(:, s);
    same_normalized_input = data.normalized_adc(:, s);
    h = two_level_hysteresis(same_normalized_input, cfg.hysteresis_on, ...
        cfg.hysteresis_off, cfg.hysteresis_initial);
    [p, d, valid] = pam3_held_output(same_adc, pcfg);
    result.output_levels(:, 1, s) = h;
    result.output_levels(:, 2, s) = p;
    result.pam3{s} = d;
    result.pam3_valid(:, s) = valid;
    for b = 1:2
        all_levels = result.output_levels(:, b, s);
        levels = all_levels(data.measure_index);
        volts = cfg.output_volts_per_level*levels;
        metrics = measure_signal(volts, cfg.fs_hz, cfg.f0_hz, ...
            cfg.max_harmonic, cfg.resistance_ohm);
        row = row_template;
        row.scenario = scenarios{s};
        row.block = blocks{b};
        row.metrics = metrics;
        clean_levels = result.output_levels(data.measure_index, b, 1);
        row.changed_from_clean_percent = 100*mean(levels ~= clean_levels);
        first = data.measure_index(1);
        if first > 1
            transitions = sum(diff([all_levels(first-1); levels]) ~= 0);
        else
            transitions = sum(diff(levels) ~= 0);
        end
        row.transitions_per_second = transitions/(numel(levels)/cfg.fs_hz);
        row.zero_percent = 100*mean(levels == 0);
        rows((s-1)*numel(blocks)+b) = row;
    end
end
result.rows = rows;
result.input_metrics = cell(2, 2);
for s = 1:2
    result.input_metrics{s, 1} = measure_signal(data.analog(data.measure_index, s), ...
        cfg.fs_hz, cfg.f0_hz, cfg.max_harmonic, cfg.resistance_ohm);
    result.input_metrics{s, 2} = measure_signal(data.normalized_adc(data.measure_index, s), ...
        cfg.fs_hz, cfg.f0_hz, cfg.max_harmonic, cfg.resistance_ohm);
end
if exist('OCTAVE_VERSION', 'builtin')
    result.runtime_product = 'GNU Octave';
else
    result.runtime_product = 'MATLAB';
end
result.runtime_version = version;
result.matlab_executed = strcmp(result.runtime_product, 'MATLAB');
result.simulink_executed = false;
if cfg.save_results && ~exist(cfg.output_dir, 'dir')
    mkdir(cfg.output_dir);
end
fprintf('\nInput: %.0f Hz sine; fs=%.0f Hz; measured noise SNR=%.3f dB\n', ...
    cfg.f0_hz, cfg.fs_hz, data.realized_snr_db);
fprintf('THD: harmonic orders 2..%d. Power: assumed %.3g V/level and %.3g ohm.\n', ...
    cfg.max_harmonic, cfg.output_volts_per_level, cfg.resistance_ohm);
fprintf('%-7s %-11s %10s %10s %10s %10s %10s\n', ...
    'Input', 'Block', 'THD(%)', 'THD+N(%)', 'Pmean(W)', 'PripRMS(W)', 'PripPP(W)');
for k = 1:numel(rows)
    r = rows(k); m = r.metrics;
    fprintf('%-7s %-11s %10.4f %10.4f %10.4f %10.4f %10.4f\n', ...
        r.scenario, r.block, m.thd_percent, m.thdn_percent, m.mean_power_w, ...
        m.power_ripple_rms_w, m.power_ripple_pp_w);
end
fprintf('Binary +/-1 output necessarily has constant resistor power here.\n');
fprintf('This is a direct signal experiment, not converter or grid power.\n');
if cfg.make_plots
    plot_comparison(result);
end
if cfg.save_results
    write_comparison_results(result);
    save(fullfile(cfg.output_dir, 'comparison_result.mat'), 'result', '-v7');
end
end
