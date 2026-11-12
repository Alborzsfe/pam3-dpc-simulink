function dpc_prepare_replay_inputs(capture, cfg)
n = size(capture.errors, 1);
t = (0:n+19)' * cfg.sample_time;
assignin('base', 'dpc_replay_cfg', cfg);
assignin('base', 'dpc_patent_cfg', dpc_patent_config(cfg));
assignin('base', 'dpc_replay_stop', t(end));
for channel = 1:2
    label = cfg.channels{channel};
    x = capture.errors(:, channel);
    adc = dpc_map_adc(x, cfg, channel);
    assignin('base', ['dpc_error_' label], [t, [x; repmat(x(end), 20, 1)]]);
    assignin('base', ['dpc_adc_' label], [t, [adc; zeros(20, 1)]]);
end
assignin('base', 'dpc_command', [t, [ones(n, 1); 2*ones(20, 1)]]);
end
