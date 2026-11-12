function [cfg, data] = prepare_simulink_comparison(model, cfg)
% Keep numeric arrays and configuration in this model's own workspace.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, 'PAM3_original'), fullfile(root, 'simulink'));
workspace = get_param(model, 'ModelWorkspace');
if nargin < 2
    if hasVariable(workspace, 'simple_cfg')
        cfg = getVariable(workspace, 'simple_cfg');
    else
        cfg = comparison_config();
    end
end
assert(cfg.hysteresis_initial == -1, 'SimpleSim:InitialRelay', ...
    'The native Relay starts off. Use hysteresis_initial = -1.');
assert(cfg.hysteresis_on > cfg.hysteresis_off);
assert(cfg.resistance_ohm > 0 && cfg.output_volts_per_level > 0);
data = make_test_input(cfg);
receiver = pam3_config();
receiver.sample_time = 1/cfg.fs_hz;
assignin(workspace, 'simple_cfg', cfg);
assignin(workspace, 'simple_pam3_cfg', receiver);
assignin(workspace, 'simple_ts', receiver.sample_time);
assignin(workspace, 'simple_stop_time', data.t(end));
% R2024b-supported numeric [time,value] matrices; no buses or timeseries.
assignin(workspace, 'simple_adc_clean', [data.t, double(data.adc(:, 1))]);
assignin(workspace, 'simple_adc_noisy', [data.t, double(data.adc(:, 2))]);
end
