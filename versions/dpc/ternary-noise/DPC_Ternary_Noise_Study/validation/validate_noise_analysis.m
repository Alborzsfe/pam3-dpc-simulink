function report = validate_noise_analysis()
% Synthetic metric checks only. Never export as converter performance results.
root = fileparts(fileparts(mfilename('fullpath')));addpath(fullfile(root,'matlab'));
cfg = dpc3_noise_config(); t = (0:round(cfg.stop_time/cfg.measurement_step))'*cfg.measurement_step;
phase = bsxfun(@plus,2*pi*50*t,[0,-2*pi/3,2*pi/3]);
v = cfg.phase_rms_voltage*sqrt(2)*sin(phase);
i = sqrt(2)*(10*sin(phase)+3*sin(3*phase)+4*sin(5*phase));
va = (2*v(:,1)-v(:,2)-v(:,3))/3;vb = (v(:,2)-v(:,3))/sqrt(3);
ia = (2*i(:,1)-i(:,2)-i(:,3))/3;ib = (i(:,2)-i(:,3))/sqrt(3);
p = 1.5*(va.*ia+vb.*ib); q = 1.5*(vb.*ia-va.*ib);
power_noise = 2*sin(2*pi*1000*t);
raw = struct('iabc',record(t,i),'vabc',record(t,v),'vdc',record(t,150+zeros(size(t))), ...
    'p',record(t,p),'q',record(t,q),'pref',record(t,p),'qref',record(t,q), ...
    'p_feedback',record(t,p+power_noise),'q_feedback',record(t,q-power_noise), ...
    'v_feedback',record(t,v),'grid_delta',record(t,zeros(numel(t),3)), ...
    'gates',record(t,repmat([0,1,0,1,0,1],numel(t),1)));
info = struct('simulink_executed',false,'closed_loop_executed',false,'control_hz',20000);
r = dpc3_noise_analyze(raw,cfg,info,'SYNTHETIC UNIT TEST');
assert(~r.simulink_executed && ~r.closed_loop_executed);
assert(abs(r.fft{1}.thd_percent-50) < 1e-8);
assert(abs(r.metrics.current_nonfundamental_percent(1)-50) < 1e-8);
assert(abs(r.metrics.p_feedback_noise_rmse-sqrt(2)) < 1e-9);
assert(r.metrics.p_tracking_rmse == 0 && r.metrics.q_tracking_rmse == 0);
assert(r.metrics.mean_equivalent_switching_hz == 0);
assert(max(abs(r.metrics.grid_voltage_thd_percent)) < 1e-9);
% Analysis retains false native flags, and the exporter rejects them.
entry.binary_limit_report = struct('passed',false,'simulink_executed',false);
entry.conventional = r;entry.proposed = r;
rejected = false;
try
    dpc3_noise_export_summary({entry},fullfile(tempdir,'dpc3_must_not_create_report'));
catch exception
    rejected = strcmp(exception.identifier,'DPC3:Provenance');
end
assert(rejected,'A synthetic result must not become a native performance report.');
report = struct('passed',true,'simulink_executed',false,'synthetic_data_used',true, ...
    'known_thd_percent',50,'known_feedback_error_rms',sqrt(2),'runtime',version);
save(fullfile(root,'validation','noise_analysis_report.mat'),'report','-v7');
fprintf('PASS synthetic analysis: known THD, broadband residual, sensor RMSE, and native-provenance rejection. NOT Simulink.\n');
end
function r = record(t,x)
r.time = t;r.signals.values = x;
end
