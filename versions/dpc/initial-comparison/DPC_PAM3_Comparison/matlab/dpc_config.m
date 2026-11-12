function cfg = dpc_config()
% First experiment: identical captured error samples, no changed gate table.
cfg.sample_time = 5e-6;
cfg.converter_stop_time = 0.12;
cfg.fallback_Ts = 5e-6; % The supplied phase-C sine sources use 5 us.
cfg.fallback_e = 50;    % EXAMPLE phase RMS voltage; not saved in the source.
cfg.release_ratio = 0.5;
cfg.patent_mode = 0;    % 0=fixed, 1=previous Q8 engineering adaptation.
cfg.analysis_start = 0;
cfg.plot_visible = 'on';
cfg.run_replay_simulink = true;
cfg.channels = {'P', 'Q'};
cfg.relay_on = [1, 1];
cfg.relay_off = [-1, -1];
cfg.relay_output_on = [1, 1];
cfg.relay_output_off = [0, 0];
end
