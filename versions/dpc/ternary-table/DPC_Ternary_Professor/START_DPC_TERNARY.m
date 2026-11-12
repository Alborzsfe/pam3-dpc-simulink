% Genuine ternary DPC, original binary limit, independent/native validation.
dpc3_root = fileparts(mfilename('fullpath'));
addpath(dpc3_root,fullfile(dpc3_root,'matlab'));
fprintf('DPC Ternary Professor | revision 2 | inclusive native Relay reference | R2024b array input\n');
dpc3_cfg = dpc3_config();
if exist('e','var') && isnumeric(e) && isscalar(e) && isreal(e) && isfinite(e) && e > 0
    dpc3_cfg.phase_rms_voltage = e;dpc3_parameter_note = 'e supplied by user workspace';
else
    dpc3_parameter_note = 'EXAMPLE e=50 V RMS; original source model did not store e';
    fprintf('%s\n',dpc3_parameter_note);
end
dpc3_validate_config(dpc3_cfg);
validate_dpc3_math();
validate_dpc3_simulink();
dpc3_results = run_dpc3_study(dpc3_cfg,dpc3_parameter_note);
