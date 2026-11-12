function report = validate_dpc3_noise_math()
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'matlab'),fullfile(root,'validation'));
c = dpc3_noise_config(); dpc3_validate_noise_config(c);
cfg = c; cfg.stop_time = 0.04;cfg.disturbance_start = 0.01;
before = rng; a = dpc3_make_stimulus(cfg,c.study_cases(7),104729); after = rng;
assert(isequal(before,after),'DPC3:RNG','Global RNG state was changed.');
b = dpc3_make_stimulus(cfg,c.study_cases(7),104729);
assert(isequal(a,b),'DPC3:Determinism','Same seed did not produce the same stimulus.');
b = dpc3_make_stimulus(cfg,c.study_cases(7),104730);
assert(~isequal(a.noise_array,b.noise_array),'Different seeds produced identical noise.');
assert(all(all(a.noise_array(1:a.first_active_sample-1,2:6) == 0)));
assert(max(abs(a.realized_active_rms-a.requested_rms)) < 1e-12);
b = dpc3_make_stimulus(cfg,c.study_cases(1),104729);assert(all(all(b.noise_array(:,2:6) == 0)));
b = dpc3_make_stimulus(cfg,c.study_cases(3),104729);
d = dpc3_make_stimulus(cfg,c.study_cases(2),104729);
assert(max(max(abs(b.noise_array(:,2:4)-3*d.noise_array(:,2:4)))) < 1e-12);
% Independent analytic harmonic/RMS check over ten exact cycles.
t = (0:39999)'*5e-6; cfg.disturbance_start = 0;
s = c.study_cases(6);s.ripple_pu = 0;
theta = bsxfun(@plus,2*pi*50*t,[0,-2*pi/3,2*pi/3]);
v = cfg.phase_rms_voltage*sqrt(2)*sin(theta)+dpc3_grid_delta(t,cfg,s);
r = quality_fft(v(:,1),5e-6,50,50);
assert(abs(r.thd_percent-100*sqrt(.05^2+.03^2)) < 1e-9);
s = c.study_cases(6); cfg.disturbance_start = 0.3;
test_t = [0,0.299999,0.3,0.301,0.378,0.799999]';
expected = dpc3_grid_delta(test_t,cfg,s);
for phase = 1:3
    expression = dpc3_grid_expression(cfg,s,phase);
    values = zeros(size(test_t));
    for k = 1:numel(test_t),u = test_t(k);values(k) = eval(expression);end %#ok<EVLDIR>
    assert(max(abs(values-expected(:,phase))) < 1e-10);
end
% A synthetic-record test of the LOG VALIDATOR, not an executed converter.
small = c;small.stop_time = 0.04;small.disturbance_start = 0.01;
stimulus = dpc3_make_stimulus(small,c.study_cases(7),104729);
t = stimulus.noise_array(:,1);nv = stimulus.noise_array(:,2:4);npq = stimulus.noise_array(:,5:6);
theta = bsxfun(@plus,2*pi*small.line_frequency*t,[0,-2*pi/3,2*pi/3]);
vr = small.phase_rms_voltage*sqrt(2)*sin(theta)+dpc3_grid_delta(t,small,c.study_cases(7));
ir = 4*sin(theta-0.2);vf = vr+nv;
truth = independent_power(vr,ir);feedback = independent_power(vf,ir)+npq;
raw = struct('vabc',record(t,vr),'iabc',record(t,ir),'v_feedback',record(t,vf), ...
    'p',record(t,truth(:,1)),'q',record(t,truth(:,2)), ...
    'p_feedback',record(t,feedback(:,1)),'q_feedback',record(t,feedback(:,2)), ...
    'noise_vabc',record(t,nv),'noise_p',record(t,npq(:,1)),'noise_q',record(t,npq(:,2)));
check = dpc3_verify_noise_logs(raw,small,c.study_cases(7),stimulus);assert(check.passed);
bad = raw;bad.p_feedback.signals.values = bad.p_feedback.signals.values+0.2;
must_fail(@() dpc3_verify_noise_logs(bad,small,c.study_cases(7),stimulus),'DPC3:PowerSensor');
bad = raw;bad.v_feedback = bad.vabc;
must_fail(@() dpc3_verify_noise_logs(bad,small,c.study_cases(7),stimulus),'DPC3:VoltageSensor');
bad = raw;bad.p = bad.p_feedback;
must_fail(@() dpc3_verify_noise_logs(bad,small,c.study_cases(7),stimulus),'DPC3:TruePower');
bad = raw;bad.noise_p.signals.values(100) = 0.5;
must_fail(@() dpc3_verify_noise_logs(bad,small,c.study_cases(7),stimulus),'DPC3:NoiseReplay');
% New noisy-feedback path against an independent ABC/quadrature oracle.
d = load(fullfile(root,'data','dpc3_noise_golden.mat'));
ch = dpc3_channel_config(c,50e-6,1,-1,true);tc = dpc3_table_config(c,50e-6,ch,ch);
max_error = 0;
for k = 1:size(d.table_inputs,1)
    x = d.table_inputs(k,:); tc.sample_time = x(18);tc.R = x(19);
    [g,a] = dpc3_table(x(1),x(2),x(3),x(4:6),x(7:9),x(10),x(11),x(12), ...
        x(13),x(14),x(15:17),tc,x(20:21));
    assert(isequal(g',d.gates(k,:)),'DPC3:NoisyGolden','Noisy table mismatch: case %d.',k);
    error = max(abs(a'-d.audit(k,:))./max(1,abs(d.audit(k,:))));
    max_error = max(max_error,error);assert(error < 1e-8);
    assert(isequal(a(6:7),x(20:21)'),'Controller ignored the measured noisy powers.');
end
samples = 0;
for n = 1:numel(d.native)
    item = d.native{n}; tc.sample_time = 1/item.fs;tc.measured_power_input = true;
    block = dpc3_mock_block(tc);dpc3_table_sfun(block);
    block.invoke('PostPropagationSetup');block.invoke('InitializeConditions');
    assert(block.NumInputPorts == 11 && block.InputPort(11).Dimensions == 2);
    for k = 1:size(item.input,1)
        x = item.input(k,:);
        inputs = {x(1),x(2),x(3),x(4:6)',x(7:9)',x(10),x(11),x(12),x(13),x(14),x(15:16)'};
        for j = 1:11, block.InputPort(j).Data = inputs{j}; end
        state = block.Dwork.Data;block.invoke('Outputs');g = block.OutputPort(1).Data;
        block.invoke('Outputs');assert(isequal(block.Dwork.Data,state) && isequal(block.OutputPort(1).Data,g));
        assert(isequal(g',item.gates(k,:)));
        assert(max(abs(block.OutputPort(2).Data'-item.audit(k,:))./max(1,abs(item.audit(k,:)))) < 1e-8);
        block.invoke('Update');samples = samples+1;
    end
end
report = struct('passed',true,'table_contexts',size(d.table_inputs,1),'callback_samples',samples, ...
    'max_relative_audit_error',max_error,'simulink_executed',false, ...
    'test_double_used',true,'runtime',version);
save(fullfile(root,'validation','noise_numerical_report.mat'),'report','-v7');
fprintf('PASS noise numerical: %d oracle contexts, %d callback samples, exact RMS/seed replay and analytic grid checks. NOT Simulink.\n', ...
    report.table_contexts,samples);
end
function result = independent_power(v,i)
result = [sum(v.*i,2),sum([v(:,2)-v(:,3),v(:,3)-v(:,1),v(:,1)-v(:,2)].*i,2)/sqrt(3)];
end
function r = record(t,x)
r.time = t;r.signals.values = x;
end
function must_fail(f,identifier)
failed = false;
try
    f();
catch exception
    failed = strcmp(exception.identifier,identifier);
end
assert(failed,'DPC3:MissingRejection','Expected validator rejection: %s',identifier);
end
