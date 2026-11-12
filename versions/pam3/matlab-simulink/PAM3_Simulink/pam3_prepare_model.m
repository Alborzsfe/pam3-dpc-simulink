function pam3_prepare_model()
% Initialize defaults only when opening the model without START_PAM3.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'));
if evalin('base', 'exist(''pam3_cfg'', ''var'')')
    cfg = evalin('base', 'pam3_cfg');
else
    cfg = pam3_config();
end
pam3_validate_config(cfg);
if ~evalin('base', 'exist(''pam3_input_master'', ''var'') && exist(''pam3_input_slave'', ''var'') && exist(''pam3_command'', ''var'')')
    demo = load(fullfile(root, 'data', 'demo_capture.mat'));
    pam3_assign_inputs(demo.adc_master, demo.adc_slave, cfg);
end
end
