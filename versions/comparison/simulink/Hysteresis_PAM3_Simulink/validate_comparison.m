function report = validate_comparison()
% Independent supplied PAM3 fixtures + analytical metric and causality checks.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'PAM3_original'));
fixture = load(fullfile(root, 'tests', 'original_golden_cases.mat'));
names = {'empty', 'tail_1', 'tail_2', 'tail_3', 'tail_4', 'tail_11', ...
    'tail_12', 'tail_13', 'tail_31', 'tail_32', 'tail_33', ...
    'strict_thresholds', 'width_1_2_3', 'random_128', 'pam3_snr_32'};
captures = 0; samples = 0;
for k = 1:numel(fixture.cases)
    c = fixture.cases{k};
    if c.dc_enabled || c.adaptive_mode ~= 0 || ~any(strcmp(c.name, names))
        continue;
    end
    d = pam3_decode(c.adc, pam3_config());
    fields = {'corrected', 'raw_levels', 'levels', 'points', 'symbols'};
    for j = 1:numel(fields)
        f = fields{j};
        assert(isequal(d.(f)(:), double(c.(f)(:))), ...
            'Compare:OriginalMismatch', 'Original PAM3 mismatch: %s, %s.', c.name, f);
    end
    assert(isequal(d.thresholds, double(c.thresholds)));
    captures = captures+1; samples = samples+numel(c.adc);
end
assert(captures > 0);
x = [-0.2; -0.199; 0; 0.199; 0.2; 0.1; -0.2];
y = two_level_hysteresis(x, 0.2, -0.2, -1);
assert(isequal(y, [-1; -1; -1; -1; 1; 1; -1]));
fs = 20000; f0 = 50; t = (0:7999)'/fs;
m = measure_signal(sin(2*pi*f0*t)+0.1*sin(6*pi*f0*t), fs, f0, 40, 1);
assert(abs(m.thd_percent-10) < 1e-8);
assert(abs(m.thdn_percent-10) < 1e-8);
m = measure_signal(sin(2*pi*f0*t), fs, f0, 40, 1);
assert(m.thd_percent < 1e-8);
assert(abs(m.mean_power_w-0.5) < 1e-12);
assert(abs(m.power_ripple_rms_w-sqrt(1/8)) < 1e-12);
assert(abs(m.power_ripple_pp_w-1) < 1e-12);
binary = 2*double(sin(2*pi*f0*t) >= 0)-1;
m = measure_signal(binary, fs, f0, 40, 1);
assert(m.mean_power_w == 1 && m.power_ripple_rms_w == 0 && m.power_ripple_pp_w == 0);
m = measure_signal(zeros(size(t)), fs, f0, 40, 1);
assert(isnan(m.thd_percent) && isnan(m.power_ripple_rms_percent));
cfg = comparison_config();
data = make_test_input(cfg);
assert(abs(data.realized_snr_db-cfg.noise_snr_db) < 1e-10);
data2 = make_test_input(cfg);
assert(isequal(data.adc, data2.adc));
% Check actual causal availability against independent source-index +20 rule.
[held, d, valid] = pam3_held_output([127*ones(30, 1); 194*ones(45, 1)], pam3_config());
events = find(valid);
keep = d.points+20 < numel(held);
assert(isequal(events-1, d.points(keep)+20));
assert(isequal(held(events), d.symbols(keep)));
assert(all(held(1:20) == 0));
report = struct('passed', true, 'original_captures', captures, ...
    'original_samples', samples, 'analytic_metrics_passed', true, ...
    'causality_passed', true, 'reproducibility_passed', true);
fprintf('PASS: %d original PAM3 captures / %d samples; metrics, causality, repeatability.\n', ...
    captures, samples);
end
