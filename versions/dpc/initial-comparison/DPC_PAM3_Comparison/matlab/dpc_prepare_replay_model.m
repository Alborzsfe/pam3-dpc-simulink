function dpc_prepare_replay_model()
% Direct model opening gets the clearly labelled synthetic educational input.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root, fullfile(root, 'matlab'), fullfile(root, 'patent_core'));
required = {'dpc_replay_cfg', 'dpc_patent_cfg', 'dpc_error_P', 'dpc_error_Q', ...
    'dpc_adc_P', 'dpc_adc_Q', 'dpc_command', 'dpc_replay_stop'};
for k = 1:numel(required)
    if ~evalin('base', ['exist(''' required{k} ''',''var'')'])
        cfg = dpc_config();
        capture = dpc_synthetic_capture();
        cfg.sample_time = capture.sample_time;
        dpc_prepare_replay_inputs(capture, cfg);
        fprintf('Model initialized with SYNTHETIC EDUCATIONAL input, not converter data.\n');
        return;
    end
end
end
