function report = validate_numeric_pipeline()
% Explicit synthetic test of metric plumbing, NEVER a converter result.
root = fileparts(fileparts(mfilename('fullpath')));
addpath(root,fullfile(root,'matlab'),fullfile(root,'patent_core'));
cfg = quality_config(); cfg.stop_time = 0.2; cfg.fft_start = 0;
t = (0:round(cfg.stop_time/cfg.measurement_step))'*cfg.measurement_step;
w = 2*pi*cfg.line_frequency*t;
current = sqrt(2)*(10*sin(w)+3*sin(3*w)+4*sin(5*w));
raw.iabc = make_log(t,[current,current,current]);
raw.vabc = make_log(t,zeros(numel(t),3));
raw.vdc = make_log(0,150); % Single-point constant reference must hold correctly.
raw.p = make_log(t,100+10*sin(2*w)); raw.pref = make_log(0,100);
raw.q = make_log(0,0); raw.qref = make_log(0,0);
tg = (0:round(cfg.stop_time/cfg.plant_step))'*cfg.plant_step;
raw.gates = make_log(tg,repmat(mod(floor(tg*2000+1e-9),2),1,6));
info = struct('method','SYNTHETIC_TEST_ONLY','control_hz',20000, ...
    'simulink_executed',false,'closed_loop_executed',false);
r = quality_analyze_run(raw,cfg,info,'Synthetic mathematical fixture, not power simulation');
assert(~r.simulink_executed && ~r.closed_loop_executed);
assert(abs(r.fft{1}.thd_percent-50) < 1e-9);
assert(abs(r.metrics.p.mean-100) < 1e-9);
assert(abs(r.metrics.p.peak_to_peak-20) < 1e-9);
assert(abs(r.metrics.p.ripple_rms-sqrt(50)) < 1e-9);
assert(abs(r.metrics.mean_equivalent_switching_hz-1000) < 1e-9);
assert(r.metrics.stationary_window);
blocked = false;
try, quality_plot_pair(r,r,tempdir); catch exception
    blocked = strcmp(exception.identifier,'QUALITY:Provenance');
end
assert(blocked,'Synthetic test data must not become professor figures.');
folder = tempname; mkdir(folder);
remove_test_files = onCleanup(@() rmdir(folder,'s'));
quality_export_run(r,folder);
saved = load(fullfile(folder,'analyzed_result.mat'));
assert(~saved.result.closed_loop_executed && ~saved.result.simulink_executed);
assert(exist(fullfile(folder,'harmonic_rms_A.csv'),'file') == 2);
report = struct('passed',true,'simulink_executed',false, ...
    'closed_loop_executed',false,'synthetic_only',true,'runtime',version);
fprintf('PASS synthetic analysis pipeline: known THD, power ripple, gate rate; professor export blocked.\n');
end

function log = make_log(time,values)
log.time = time; log.signals.values = values;
end
