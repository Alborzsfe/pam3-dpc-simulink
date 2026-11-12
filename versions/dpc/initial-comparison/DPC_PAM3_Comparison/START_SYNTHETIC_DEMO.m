% Separate demo without the converter/Simscape Electrical dependency.
dpc_root = fileparts(mfilename('fullpath'));
addpath(dpc_root, fullfile(dpc_root, 'matlab'), fullfile(dpc_root, 'patent_core'));
dpc_cfg = dpc_config();
validate_dpc_core();
dpc_capture = dpc_synthetic_capture();
dpc_cfg.sample_time = dpc_capture.sample_time;
dpc_result = run_dpc_comparison(dpc_capture, dpc_cfg);
fprintf('\nEducational synthetic demo only. Results: %s\n', ...
    fullfile(dpc_root, 'results', 'synthetic_educational'));
