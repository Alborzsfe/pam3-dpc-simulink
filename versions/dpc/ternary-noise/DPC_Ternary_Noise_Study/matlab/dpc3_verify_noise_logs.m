function report = dpc3_verify_noise_logs(raw,cfg,s,stimulus)
% Native-run checks: exact replay, physical grid, and truth/feedback separation.
n = size(stimulus.noise_array,1); dt = cfg.noise_sample_time;
v = dpc3_log_samples(raw.noise_vabc,dt,n,3,'voltage noise');
p = dpc3_log_samples(raw.noise_p,dt,n,1,'power P noise');
q = dpc3_log_samples(raw.noise_q,dt,n,1,'power Q noise');
replay_error = max(max(abs([v,p,q]-stimulus.noise_array(:,2:6))));
assert(replay_error <= 1e-12*max(1,max(stimulus.requested_rms)), ...
    'DPC3:NoiseReplay','The model did not replay the exact prescribed sensor noise.');
t = double(raw.vabc.time(:));
vr = quality_log_to_grid(raw.vabc,t,'true voltage');
ir = quality_log_to_grid(raw.iabc,t,'true current');
vf = quality_log_to_grid(raw.v_feedback,t,'feedback voltage');
noise_log.time = stimulus.noise_array(:,1);
noise_log.signals.values = stimulus.noise_array(:,2:6);
noise = quality_log_to_grid(noise_log,t,'expected sensor noise');
voltage_error = max(max(abs(vf-vr-noise(:,1:3))));
theta = bsxfun(@plus,2*pi*cfg.line_frequency*t,[0,-2*pi/3,2*pi/3]);
expected_grid = cfg.phase_rms_voltage*sqrt(2)*sin(theta)+dpc3_grid_delta(t,cfg,s);
grid_error = max(max(abs(vr-expected_grid)));
assert(voltage_error < 1e-8*max(1,cfg.phase_rms_voltage),'DPC3:VoltageSensor','Voltage sensor wiring mismatch.');
assert(grid_error < 1e-6*max(1,cfg.phase_rms_voltage),'DPC3:PhysicalGrid', ...
    'Physical voltage differs from prescribed grid (max %.6g V). Check series source polarity/phase.',grid_error);
true_power = abc_power(vr,ir); before_noise = abc_power(vf,ir);
logged_true = [quality_log_to_grid(raw.p,t,'true P'),quality_log_to_grid(raw.q,t,'true Q')];
feedback = [quality_log_to_grid(raw.p_feedback,t,'feedback P'),quality_log_to_grid(raw.q_feedback,t,'feedback Q')];
truth_error = max(max(abs(logged_true-true_power)));
feedback_error = max(max(abs(feedback-before_noise-noise(:,4:5))));
scale = max(1,max(abs([true_power(:);feedback(:)])));
assert(truth_error < 1e-8*scale,'DPC3:TruePower','True-power monitor is inconsistent with physical v/i.');
assert(feedback_error < 1e-8*scale,'DPC3:PowerSensor','Power sensor injection or calculator mismatch.');
report = struct('passed',true,'simulink_executed',true,'seed',stimulus.seed, ...
    'case_id',s.id,'replay_max_error',replay_error,'voltage_feedback_max_error_V',voltage_error, ...
    'physical_grid_max_error_V',grid_error,'true_power_max_error',truth_error, ...
    'power_feedback_max_error',feedback_error);
end
function pq = abc_power(v,i)
va = (2*v(:,1)-v(:,2)-v(:,3))/3; vb = (v(:,2)-v(:,3))/sqrt(3);
ia = (2*i(:,1)-i(:,2)-i(:,3))/3; ib = (i(:,2)-i(:,3))/sqrt(3);
pq = 1.5*[va.*ia+vb.*ib,vb.*ia-va.*ib];
end
