function result = quality_analyze_run(raw, cfg, info, parameter_note)
n = round(cfg.stop_time/cfg.measurement_step);
time = (0:n)'*cfg.measurement_step;
signals = struct(); names = {'iabc', 'vabc', 'vdc', 'p', 'pref', 'q', 'qref'};
for k = 1:numel(names)
    signals.(names{k}) = quality_log_to_grid(raw.(names{k}), time, names{k});
end
assert(size(signals.iabc, 2) == 3 && size(signals.vabc, 2) == 3);
start_index = round(cfg.fft_start/cfg.measurement_step)+1;
count = round(cfg.fft_cycles/(cfg.line_frequency*cfg.measurement_step));
indices = (start_index:start_index+count-1)';
assert(indices(end) <= numel(time));
phase_fft = cell(1, 3);
for phase = 1:3
    phase_fft{phase} = quality_fft(signals.iabc(indices, phase), cfg.measurement_step, ...
        cfg.line_frequency, cfg.max_harmonic);
end
metrics = struct();
metrics.p = quality_ripple(signals.p(indices));
metrics.q = quality_ripple(signals.q(indices));
metrics.vdc = quality_ripple(signals.vdc(indices));
metrics.p_tracking_rmse = sqrt(mean((signals.pref(indices)-signals.p(indices)).^2));
metrics.q_tracking_rmse = sqrt(mean((signals.qref(indices)-signals.q(indices)).^2));
metrics.dc_tracking_error_percent = 100*(metrics.vdc.mean-cfg.dc_reference)/cfg.dc_reference;
half = floor(numel(indices)/2);
early = indices(1:half); late = indices(end-half+1:end);
early_rms = sqrt(mean(signals.iabc(early, :).^2, 1));
late_rms = sqrt(mean(signals.iabc(late, :).^2, 1));
metrics.current_rms_drift_fraction = max(abs(late_rms-early_rms)./max(1e-9, (late_rms+early_rms)/2));
metrics.dc_mean_drift_fraction = abs(mean(signals.vdc(late))-mean(signals.vdc(early)))/ ...
    max(1, abs(metrics.vdc.mean));
metrics.stationary_window = metrics.current_rms_drift_fraction <= cfg.steady_drift_limit && ...
    metrics.dc_mean_drift_fraction <= cfg.steady_drift_limit;
% Count the actual six gate transitions at the common PLANT rate.
gate_time = (round(cfg.fft_start/cfg.plant_step): ...
    round((cfg.fft_start+cfg.fft_cycles/cfg.line_frequency)/cfg.plant_step))'*cfg.plant_step;
gates = quality_log_to_grid(raw.gates, gate_time, 'gates');
assert(size(gates, 2) == 6 && all(ismember(gates(:), [0,1])));
metrics.gate_transitions_per_device = sum(diff(gates, 1, 1) ~= 0, 1);
duration = gate_time(end)-gate_time(1);
metrics.equivalent_switching_hz_per_device = metrics.gate_transitions_per_device/(2*duration);
metrics.mean_equivalent_switching_hz = mean(metrics.equivalent_switching_hz_per_device);
result = struct('cfg', cfg, 'info', info, 'time', time, 'signals', signals, ...
    'fft_indices', indices, 'fft', {phase_fft}, 'metrics', metrics, 'parameter_note', parameter_note, ...
    'simulink_executed', info.simulink_executed, ...
    'closed_loop_executed', info.closed_loop_executed, 'runtime', version);
end
