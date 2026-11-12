function stimulus = dpc3_make_stimulus(cfg,study_case,seed)
% An OFFLINE finite Gaussian test record; no random block inside the controller.
% Global RNG state is restored, including on errors. Reused by all three methods.
old = rng; restore_rng = onCleanup(@() rng(old));
rng(seed,'twister');
time = (0:round(cfg.stop_time/cfg.noise_sample_time))'*cfg.noise_sample_time;
first = round(cfg.disturbance_start/cfg.noise_sample_time)+1;
active = first:numel(time);
z = randn(numel(active),5);
z = bsxfun(@minus,z,mean(z,1));
z = bsxfun(@rdivide,z,sqrt(mean(z.^2,1)));
sigma = [repmat(cfg.phase_rms_voltage*study_case.voltage_noise_rms_pu,1,3), ...
    study_case.power_noise_rms];
noise = zeros(numel(time),5);
noise(active,:) = bsxfun(@times,z,sigma);
stimulus = struct('seed',seed,'study_case',study_case,'noise_array',[time,noise], ...
    'sample_time',cfg.noise_sample_time,'first_active_sample',first, ...
    'requested_rms',sigma,'realized_active_rms',sqrt(mean(noise(active,:).^2,1)), ...
    'generator','twister / finite record centered and normalized per channel', ...
    'revision',cfg.study_revision);
end
