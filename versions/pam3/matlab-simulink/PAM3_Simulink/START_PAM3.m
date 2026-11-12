% Open this project folder in MATLAB and run START_PAM3.
pam3_root = fileparts(mfilename('fullpath'));
addpath(pam3_root);
addpath(fullfile(pam3_root, 'matlab'));
addpath(fullfile(pam3_root, 'models'));
pam3_cfg = pam3_config();
validate_matlab(true);
% Rebuild via official Simulink APIs rather than relying on an untested container.
pam3_result = run_pam3_demo(pam3_cfg, true);
