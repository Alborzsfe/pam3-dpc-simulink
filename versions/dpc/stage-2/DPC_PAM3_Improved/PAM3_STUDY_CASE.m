function result=PAM3_STUDY_CASE(method,noiseStd,seed,cfg)
root=fileparts(mfilename('fullpath'));
model=BUILD_PAM3_STUDY_MODEL(method,noiseStd,seed,cfg);
PAM3_STUDY_INSTRUMENT(model);
fprintf('Simulating %s, sensor noise std=[%g V, %g A], seed=%d ...\n',method,noiseStd,seed);
simOut=sim(model,'ReturnWorkspaceOutputs','on');
labels={'P','Q','I','Vdc','Pref','sp','sq','S1','S2','S3', ...
    'V','Vmeasured','Imeasured','NoiseV','NoiseI','Pmeasured','Qmeasured','Qref','Diagnostics'};
raw=struct();
for k=1:numel(labels),raw.(labels{k})=simOut.get(['study_' labels{k}]);end
m=PAM3_MEASURE_SIGNALS(raw,cfg);
m.Method=string(method);m.NoiseVoltageStd_V=noiseStd(1);
m.NoiseCurrentStd_A=noiseStd(2);m.Seed=seed;
m.SamplingFrequency_Hz=1/cfg.Ts;m.FilterInductance_H=cfg.modelL;
m.BaselineBandScale=1;
if strcmp(method,'baseline') && isfield(cfg,'baselineBandScale'),m.BaselineBandScale=cfg.baselineBandScale;end
m.SourceTHDTarget_pct=0;if isfield(cfg,'sourceTHD'),m.SourceTHDTarget_pct=100*cfg.sourceTHD;end
m.ReferenceMode="outer_voltage";if isfield(cfg,'referenceMode'),m.ReferenceMode=string(cfg.referenceMode);end
m.Role=string(method);if isfield(cfg,'role'),m.Role=string(cfg.role);end
result.metrics=m;result.raw=raw;result.model=model;
% Save each completed case, even if a later case fails.
folder=fullfile(root,'results');
if isfield(cfg,'outputFolder'),folder=cfg.outputFolder;end
if ~isfolder(folder),mkdir(folder);end
save(fullfile(folder,sprintf('%s_nv%g_ni%g_seed%d.mat',method,noiseStd(1),noiseStd(2),seed)), ...
    'result','cfg');
end
