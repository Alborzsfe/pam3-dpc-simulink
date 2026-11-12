function r = dpc3_noise_analyze(raw,cfg,info,parameter_note)
r = quality_analyze_run(raw,cfg,info,parameter_note);
fields = {'v_feedback','p_feedback','q_feedback','grid_delta'};
for k = 1:numel(fields)
    r.signals.(fields{k}) = quality_log_to_grid(raw.(fields{k}),r.time,fields{k});
end
ix = r.fft_indices;
for k = 1:3
    voltage_fft = quality_fft(r.signals.vabc(ix,k),cfg.measurement_step,cfg.line_frequency,cfg.max_harmonic);
    r.metrics.grid_voltage_thd_percent(k) = voltage_fft.thd_percent;
end
r.metrics.p_feedback_noise_rmse = sqrt(mean((r.signals.p_feedback(ix)-r.signals.p(ix)).^2));
r.metrics.q_feedback_noise_rmse = sqrt(mean((r.signals.q_feedback(ix)-r.signals.q(ix)).^2));
r.metrics.p_feedback_tracking_rmse = sqrt(mean((r.signals.pref(ix)-r.signals.p_feedback(ix)).^2));
r.metrics.q_feedback_tracking_rmse = sqrt(mean((r.signals.qref(ix)-r.signals.q_feedback(ix)).^2));
% Broadband AC residual includes interharmonics/noise; HARMONIC THD alone does not.
phase = 2*pi*cfg.line_frequency*r.time(ix);
design = [ones(numel(ix),1),sin(phase),cos(phase)];
for k = 1:3
    y = r.signals.iabc(ix,k); fit = design*(design\y);
    r.metrics.current_nonfundamental_rms_A(k) = sqrt(mean((y-fit).^2));
    r.metrics.current_nonfundamental_percent(k) = ...
        100*r.metrics.current_nonfundamental_rms_A(k)/max(eps,r.fft{k}.fundamental_rms);
end
if isfield(raw,'audit')
    audit = dpc3_log_samples(raw.audit,1/info.control_hz,round(cfg.stop_time*info.control_hz)+1,21,'ternary audit');
    active = ((0:size(audit,1)-1)'/info.control_hz >= cfg.disturbance_start);
    r.zero_fraction_p = mean(audit(active,1) == 0); r.zero_fraction_q = mean(audit(active,2) == 0);
    r.guard_fraction = mean(audit(active,12));
else
    r.zero_fraction_p = NaN; r.zero_fraction_q = NaN; r.guard_fraction = NaN;
end
end
