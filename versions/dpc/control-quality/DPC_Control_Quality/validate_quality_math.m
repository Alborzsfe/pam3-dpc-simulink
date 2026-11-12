function report = validate_quality_math()
% Numerical validation only: does not execute the converter or claim its THD.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'matlab'), fullfile(root,'patent_core'));
fixtures = load(fullfile(root,'data','quality_fixtures.mat'));
samples = 0;
for c = 1:numel(fixtures.cases)
    item = fixtures.cases{c}; cfg = quality_config();
    cfg.proposed_variant = strtrim(item.variant);
    controller = quality_controller_config(cfg, 1/item.fs, 1, -1);
    state = quality_controller_initial(controller);
    actual = zeros(size(item.errors));
    for k = 1:numel(item.errors)
        [state, actual(k)] = quality_controller_step(state, item.errors(k), controller);
    end
    assert(isequal(actual, item.expected), 'QUALITY:Golden', ...
        'Independent controller fixture failed, case %d.', c);
    samples = samples+numel(actual);
end
dt = 5e-6; t = (0:39999)'*dt; w = 2*pi*50*t;
% RMS amplitudes 10 A fundamental, 3 A h3, 4 A h5 => exactly 50%.
x = 7+sqrt(2)*(10*sin(w+0.37)+3*cos(3*w)+4*sin(5*w+0.8));
r = quality_fft(x,dt,50,50);
assert(abs(r.thd_percent-50) < 1e-9 && abs(r.fundamental_rms-10) < 1e-10);
assert(abs(r.dc-7) < 1e-10);
r = quality_fft(x+sqrt(2)*6*sin(51*w),dt,50,50);
assert(abs(r.thd_percent-50) < 1e-9 && abs(r.residual_rms-6) < 1e-9);
r = quality_fft(sqrt(2)*10*sin(w),dt,50,50); assert(r.thd_percent < 1e-9);
r = quality_fft(ones(size(w)),dt,50,50); assert(isnan(r.thd_percent));
failed = false;
try, quality_fft(x(1:end-1),dt,50,50); catch, failed = true; end
assert(failed, 'Noncoherent FFT window must be rejected.');
r = quality_ripple([1,3,1,3]);
assert(r.mean == 2 && r.peak_to_peak == 2 && r.ripple_rms == 1);
r = quality_ripple([-1,1]); assert(isnan(r.peak_to_peak_percent_of_abs_mean));
log.time = [0;1;1;2]; log.signals.values = [0;1;2;4];
y = quality_log_to_grid(log,[0;0.5;1;1.5;2],'duplicates'); assert(isequal(y,[0;0;2;2;4]));
log.time = 0; log.signals.values = reshape([1,2,3],[1,3,1]);
y = quality_log_to_grid(log,[0;1;2],'constant vector'); assert(isequal(y,repmat([1,2,3],3,1)));
log.time = [0;1;2;3]; log.signals.values = reshape(1:12,[1,3,4]);
y = quality_log_to_grid(log,[0;1;2;3],'3D vector'); assert(isequal(y,reshape(1:12,3,4)'));
quality_validate_config(quality_config());
report = struct('passed',true,'controller_cases',numel(fixtures.cases), ...
    'controller_samples',samples,'known_FFT_checks',5,'ripple_checks',2, ...
    'resampling_checks',3,'simulink_executed',false,'runtime',version);
fprintf('PASS numerical core: %d independent cases, %d samples; FFT/THD, ripple, resampling checked.\n', ...
    report.controller_cases, report.controller_samples);
end
