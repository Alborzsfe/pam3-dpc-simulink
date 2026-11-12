% One command: build -> open -> simulate -> validate -> plot actual results.
simple_root = fileparts(mfilename('fullpath'));
addpath(simple_root, fullfile(simple_root, 'simulink'), ...
    fullfile(simple_root, 'PAM3_original'));
cfg = comparison_config();
cfg.output_dir = fullfile(simple_root, 'results_simulink');
test_report = validate_comparison();
model = build_simulink_comparison(cfg);
fprintf('Running both clean and noisy paths in Simulink Normal mode...\n');
simulation_output = sim(model, 'ReturnWorkspaceOutputs', 'on');
[result, simulink_report] = analyze_simulink_comparison(simulation_output, cfg);
save(fullfile(cfg.output_dir, 'simulink_validation.mat'), ...
    'simulink_report', 'test_report', '-v7');
fprintf('PASS Simulink: %d output samples match the MATLAB reference.\n', ...
    simulink_report.output_samples_checked);
fprintf('Actual model results saved in results_simulink.\n');
