function [result, report] = analyze_simulink_comparison(simout, cfg)
% Analyze ACTUAL model logs; require exact ADC, level and decoder-trace match.
% A plain struct is accepted only for offline harness tests, never as evidence
% that Simulink executed. Native runs pass a Simulink.SimulationOutput object.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, 'PAM3_original'));
reference_cfg = cfg;
reference_cfg.make_plots = false;
reference_cfg.save_results = false;
reference = run_comparison(reference_cfg);
data = reference.input; n = numel(data.t);
time = read_log(simout, 'simple_time');
assert(numel(time) == n && ...
    max(abs(time(:)-data.t)) < max(1e-12, (1/cfg.fs_hz)*1e-7), ...
    'SimpleSim:Time', 'Sample count or simulation clock differs from the source.');
result = reference;
result.config = cfg;
result.output_levels = zeros(n, 2, 2);
result.logged_power_w = zeros(n, 2, 2);
cases = {'clean', 'noisy'};
for s = 1:2
    levels = read_log(simout, ['levels_' cases{s}]);
    power = read_log(simout, ['power_' cases{s}]);
    debug = read_log(simout, ['debug_' cases{s}]);
    assert(isequal(size(levels), [n, 2]) && isequal(size(power), [n, 2]) && ...
        isequal(size(debug), [n, 19]), ...
        'SimpleSim:Dimensions', 'Unexpected log shape for %s.', cases{s});
    assert_same(debug(:, 1), data.adc(:, s), ['ADC ' cases{s}]);
    assert_same(levels, reference.output_levels(:, :, s), ['levels ' cases{s}]);
    assert_same(debug(:, 2:end), reference.pam3{s}.trace(1:n, :), ...
        ['original receiver trace ' cases{s}]);
    expected_power = (cfg.output_volts_per_level*levels).^2/cfg.resistance_ohm;
    assert(max(abs(power(:)-expected_power(:))) <= ...
        1e-12*max(1, max(abs(expected_power(:)))), ...
        'SimpleSim:Power', 'Native power blocks disagree with v^2/R.');
    result.output_levels(:, :, s) = levels;
    result.logged_power_w(:, :, s) = power;
    result.pam3{s} = pam3_trace_decode(debug(:, 2:end));
    result.pam3_valid(:, s) = debug(:, 2) ~= 0;
end
ix = data.measure_index;
for s = 1:2
    for b = 1:2
        k = (s-1)*2+b;
        all_levels = result.output_levels(:, b, s);
        levels = all_levels(ix);
        volts = cfg.output_volts_per_level*levels;
        m = measure_signal(volts, cfg.fs_hz, cfg.f0_hz, cfg.max_harmonic, cfg.resistance_ohm);
        % Power ripple below is measured from native Simulink power-block logs.
        p = result.logged_power_w(ix, b, s);
        m.mean_power_w = mean(p);
        m.power_ripple_pp_w = max(p)-min(p);
        m.power_ripple_rms_w = sqrt(mean((p-mean(p)).^2));
        m.power_ripple_pp_percent = NaN;
        m.power_ripple_rms_percent = NaN;
        if m.mean_power_w > 1e-12
            m.power_ripple_pp_percent = 100*m.power_ripple_pp_w/m.mean_power_w;
            m.power_ripple_rms_percent = 100*m.power_ripple_rms_w/m.mean_power_w;
        end
        result.rows(k).metrics = m;
        result.rows(k).changed_from_clean_percent = ...
            100*mean(levels ~= result.output_levels(ix, b, 1));
        if ix(1) > 1
            transitions = sum(diff([all_levels(ix(1)-1); levels]) ~= 0);
        else
            transitions = sum(diff(levels) ~= 0);
        end
        result.rows(k).transitions_per_second = transitions/(numel(ix)/cfg.fs_hz);
        result.rows(k).zero_percent = 100*mean(levels == 0);
    end
end
is_native = isa(simout, 'Simulink.SimulationOutput');
result.simulink_executed = is_native;
result.source = 'Logged Simulink signals';
if ~is_native
    result.source = 'Offline harness test with synthetic logs; NOT a Simulink run';
end
report = struct('passed', true, 'simulink_executed', is_native, ...
    'adc_samples_checked', 2*n, 'output_samples_checked', 4*n, ...
    'trace_values_checked', 2*n*18, 'power_samples_checked', 4*n, ...
    'all_levels_and_traces_exact_match', true, 'time_grid_match', true);
result.simulink_validation = report;
fprintf('\nMeasured from %s:\n', result.source);
for k = 1:4
    row = result.rows(k); m = row.metrics;
    fprintf('%s / %s: THD %.4f%%, THD+N %.4f%%, power ripple RMS %.6f W\n', ...
        row.scenario, row.block, m.thd_percent, m.thdn_percent, m.power_ripple_rms_w);
end
if cfg.save_results
    if ~exist(cfg.output_dir, 'dir')
        mkdir(cfg.output_dir);
    end
end
if cfg.make_plots
    plot_comparison(result);
end
if cfg.save_results
    write_comparison_results(result);
    save(fullfile(cfg.output_dir, 'comparison_result.mat'), 'result', '-v7');
end
end

function array = read_log(simout, name)
if isstruct(simout)
    assert(isfield(simout, name), 'SimpleSim:MissingLog', 'Missing log %s.', name);
    array = simout.(name);
else
    array = simout.get(name);
end
assert(isnumeric(array) && isreal(array) && all(isfinite(array(:))), ...
    'SimpleSim:LogFormat', 'Log %s must be a finite numeric array.', name);
array = double(array);
end

function assert_same(actual, expected, label)
assert(isequal(size(actual), size(expected)), 'SimpleSim:Shape', ...
    'Shape mismatch for %s.', label);
bad = find(actual ~= expected, 1);
if ~isempty(bad)
    [sample, channel] = ind2sub(size(actual), bad);
    error('SimpleSim:Mismatch', ...
        '%s mismatch at sample %d, column %d: actual %.17g, expected %.17g.', ...
        label, sample, channel, actual(bad), expected(bad));
end
end
