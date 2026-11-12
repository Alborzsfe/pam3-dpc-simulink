% Extract the complete ZIP, open this folder in MATLAB, and run START_COMPARE.
root = fileparts(mfilename('fullpath'));
addpath(root);
addpath(fullfile(root, 'PAM3_original'));
cfg = comparison_config();
test_report = validate_comparison();
result = run_comparison(cfg);
fprintf('\nDone. Open results/summary.csv and the PNG figures.\n');
