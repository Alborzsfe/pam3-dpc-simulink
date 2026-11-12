% Build, save and open the native block diagram without running a simulation.
simple_root = fileparts(mfilename('fullpath'));
addpath(simple_root, fullfile(simple_root, 'simulink'), ...
    fullfile(simple_root, 'PAM3_original'));
cfg = comparison_config();
model = build_simulink_comparison(cfg);
fprintf('Double-click Clean_Test, Noisy_Test, or their PAM3_Detector subsystem.\n');
