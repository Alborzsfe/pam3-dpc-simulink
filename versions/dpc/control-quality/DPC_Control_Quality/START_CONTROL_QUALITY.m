% Four CLOSED-LOOP simulations: conventional/proposed at 20 and 200 kHz Fs.
quality_root = fileparts(mfilename('fullpath'));
addpath(quality_root, fullfile(quality_root, 'matlab'), fullfile(quality_root, 'patent_core'));
fprintf('DPC Control Quality | R2024b input-array revision 2026-10-15\n');
quality_cfg = quality_config();
if exist('e', 'var') && isnumeric(e) && isscalar(e)
    quality_cfg.phase_rms_voltage = e;
    quality_parameter_note = 'e supplied by user workspace';
else
    quality_parameter_note = 'EXAMPLE e=50 V RMS; original value was not stored in the supplied model';
    fprintf('%s\n', quality_parameter_note);
end
quality_validate_config(quality_cfg);
validate_quality_math();
validate_quality_simulink();
quality_results = run_quality_study(quality_cfg, quality_parameter_note);
