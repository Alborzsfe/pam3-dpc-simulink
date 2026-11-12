function model=OPEN_PROFESSOR_MODEL(fsHz,LmH,method,noisy)
% Example: OPEN_PROFESSOR_MODEL(20000,10,'predictive',true)
if nargin<1,fsHz=20000;end
if nargin<2,LmH=10;end
if nargin<3,method='predictive';end
if nargin<4,noisy=true;end
assert(ismember(fsHz,[20000 40000]) && ismember(LmH,[10 15]), ...
    'PAM3Study:Scenario','Use 20000/40000 Hz and 10/15 mH.');
cfg=pam3_study_config();cfg.Ts=1/fsHz;cfg.modelL=LmH*1e-3;
noise=[0 0];if noisy,noise=cfg.noiseStd;end
model=BUILD_PAM3_STUDY_MODEL(method,noise,cfg.cleanSeed,cfg);
PAM3_STUDY_INSTRUMENT(model,cfg);
open_system(model);
fprintf('Model: %s, fs=%g Hz, L=%g mH, sensor noise=[%g V,%g A].\n', ...
    model,fsHz,LmH,noise);
fprintf('Study_Sensor_Noise: voltage/current noise. Scope: physical P/Q. Scope4: physical Iabc.\n');
end
