function report = validate_simulink_harness()
% Offline collection/checker regression. This does NOT run Simulink.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, 'PAM3_original'), fullfile(root, 'simulink'));
cfg = comparison_config(); cfg.make_plots = false; cfg.save_results = false;
baseline = load(fullfile(root, 'results_reference', 'comparison_result.mat'));
reference = baseline.result;
logs = struct();
logs.simple_time = reference.input.t;
cases = {'clean', 'noisy'};
for s = 1:2
    levels = reference.output_levels(:, :, s);
    logs.(['levels_' cases{s}]) = levels;
    logs.(['power_' cases{s}]) = levels.^2;
    logs.(['debug_' cases{s}]) = ...
        [reference.input.adc(:, s), reference.pam3{s}.trace(1:numel(reference.input.t), :)];
end
[actual, check] = analyze_simulink_comparison(logs, cfg);
assert(check.passed && ~check.simulink_executed && ~actual.simulink_executed);
assert(isequal(actual.output_levels, reference.output_levels));
for k = 1:4
    assert(abs(actual.rows(k).metrics.thd_percent-reference.rows(k).metrics.thd_percent) < 1e-9);
    assert(abs(actual.rows(k).metrics.power_ripple_rms_w- ...
        reference.rows(k).metrics.power_ripple_rms_w) < 1e-12);
end
% Deliberately wrong first sample must be rejected, not silently corrected.
bad = logs; bad.debug_clean(1, 1) = bad.debug_clean(1, 1)+1;
rejected = false;
try
    analyze_simulink_comparison(bad, cfg);
catch err
    rejected = strcmp(err.identifier, 'SimpleSim:Mismatch');
end
assert(rejected);
report = struct('passed', true, 'simulink_executed', false, ...
    'offline_log_analysis_passed', true, 'bad_adc_log_rejected', true, ...
    'output_samples_checked', check.output_samples_checked);
fprintf('PASS offline harness only: sample matching, metrics, and mismatch rejection.\n');
end
