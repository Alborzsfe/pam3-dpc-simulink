% Run from a fresh extracted DPC_Ternary_Noise_Study directory (MATLAB R2024b).
dpc3_noise_root = fileparts(mfilename('fullpath'));
addpath(dpc3_noise_root,fullfile(dpc3_noise_root,'matlab'));
fprintf('DPC Ternary Noise Study | revision 1 | shared noise / physical distortion / true-power metrics\n');
dpc3_noise_cfg = dpc3_noise_config();
if exist('e','var') && isnumeric(e) && isscalar(e) && isreal(e) && isfinite(e) && e > 0
    dpc3_noise_cfg.phase_rms_voltage = e;
    dpc3_noise_parameter_note = 'e supplied by user workspace';
else
    dpc3_noise_parameter_note = 'EXAMPLE e=50 V RMS per phase; original source model did not store e';
    fprintf('%s\n',dpc3_noise_parameter_note);
end
dpc3_validate_noise_config(dpc3_noise_cfg);
validate_dpc3_math();
validate_dpc3_noise_math();
validate_dpc3_simulink();
validate_dpc3_noise_simulink();
dpc3_noise_manifest = run_dpc3_noise_study(dpc3_noise_cfg,dpc3_noise_parameter_note);
