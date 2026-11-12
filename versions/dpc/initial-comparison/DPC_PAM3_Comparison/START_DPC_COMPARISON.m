% Execute the supplied converter, then replay EXACTLY the same captured errors.
dpc_root = fileparts(mfilename('fullpath'));
addpath(dpc_root, fullfile(dpc_root, 'matlab'), fullfile(dpc_root, 'patent_core'));
dpc_cfg = dpc_config();
validate_dpc_core();
validate_dpc_capture();
[dpc_capture, dpc_cfg] = record_dpc_errors(dpc_cfg);
dpc_result = run_dpc_comparison(dpc_capture, dpc_cfg);
fprintf('\nCompleted converter capture and identical-input comparison.\n');
fprintf('Results: %s\n', fullfile(dpc_root, 'results', 'actual_converter'));
