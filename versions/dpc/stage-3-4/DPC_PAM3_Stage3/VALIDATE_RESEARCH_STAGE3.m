function VALIDATE_RESEARCH_STAGE3()
% MATLAB-only fixtures for the inputs and metrics. Not a plant simulation.
[cfg,cases]=research_stage3_config();
assert(numel(cases)==7 && sum(arrayfun(@(s)numel(s.Seeds),cases))==11);
assert(isequal([cases.PhaseA_RMS_V],[50 40 30 40 30 50 50]));
assert(isequal([cases.Qafter_var],[0 0 0 0 0 80 -80]));
assert(isequal(cfg.frozenBaselineBands,[.8 .5]));
assert(isequal(cases(4).NoiseStd,[.5 .05]) && isequal(cases(4).Seeds,cases(5).Seeds));
% Verify the default source remains compatible with the original callers.
v=pam3_grid_wave(.017,50,50,.05);
assert(isequal(v,pam3_grid_wave(.017,50,50,.05,[1 1 1])));

% Continuous phase sources observed on the same grid as the production logs.
t=(0:round(cfg.stopTime/cfg.Ts))'*cfg.Ts;t(end)=cfg.stopTime;
wave=zeros(numel(t),3);
for k=1:numel(t),wave(k,:)=pam3_grid_wave(t(k),50,50,0)';end
raw.Pref=signal(t,400*ones(size(t)));
raw.Qref=signal(t,zeros(size(t)));
for a=[50 40 30]
    cfg.sourcePhaseScale=[a/50 1 1];
    v=wave;
    for k=1:numel(t),v(k,:)=pam3_grid_wave(t(k),50,50,0,cfg.sourcePhaseScale)';end
    raw.V=signal(t,v);
    o=PAM3_STAGE3_OBSERVATIONS(raw,cfg);
    assert(o.VoltageVerified && o.ReferencesVerified);
    assert(max(abs([o.Va_RMS_V o.Vb_RMS_V o.Vc_RMS_V]-[a 50 50]))<1e-8);
    assert(isnan(o.Q_Overshoot_pct));
end
cfg.sourcePhaseScale=[1 1 1];raw.V=signal(t,wave);
cfg.referenceMode='stepQ';cfg.window=cfg.stepAnalysisWindow;
for direction=[-1 1]
    cfg.Qafter=80*direction;
    qr=zeros(size(t));
    for k=1:numel(t)
        [~,qr(k)]=pam3_reference_profile(t(k),cfg.stepTime,400,400,0,cfg.Qafter);
    end
    q=qr;q(t>=.24 & t<.25)=96*direction;
    p=400*ones(size(t));p(t>=.24 & t<.25)=425;
    raw.P=signal(t,p);raw.Q=signal(t,q);raw.Qref=signal(t,qr);
    o=PAM3_STAGE3_OBSERVATIONS(raw,cfg);
    assert(o.ReferencesVerified && o.VoltageVerified);
    assert(o.Q_Overshoot_var==16 && o.Q_Overshoot_pct==20);
    assert(o.P_MaxAbsTrackingError_W==25);
    bad=raw;bad.Qref=signal(t,zeros(size(t)));
    o=PAM3_STAGE3_OBSERVATIONS(bad,cfg);
    assert(~o.ReferencesVerified);
end

b=comparison_fixture();a=b;a.I_THD_mean_pct=1.6;
a.SwitchLegA_Hz=4250;a.SwitchCyclesPerLeg_Hz=mean([4250 4000 4000]);
a.Q_Overshoot_pct=10;a.Q_Overshoot_var=8;
c=PAM3_STAGE3_COMPARE(b,a,cfg,true);
assert(abs(c.THD_Change_pct+20)<1e-12 && ~c.SwitchingComparable && c.InputsVerified);
assert(c.MaxSwitchingMismatch_pct==6.25 && c.Q_Overshoot_Change_pp==10);
assert(isnan(c.Q_Overshoot_pct_Change_pct));
a.SwitchLegA_Hz=4160;a.SwitchCyclesPerLeg_Hz=mean([4160 4000 4000]);
c=PAM3_STAGE3_COMPARE(b,a,cfg,false);
assert(c.SwitchingComparable && ~c.InputsVerified);
fprintf('PASS: Stage 3 source, reference, signed overshoot and comparison fixtures.\n');
end

function s=signal(t,x)
s=struct('time',t,'signals',struct('values',x));
end

function b=comparison_fixture()
b=struct('Case',"fixture",'Scenario',"fixture",'L_mH',15,'Seed',321, ...
    'Va_Target_RMS_V',50,'Vb_Target_RMS_V',50,'Vc_Target_RMS_V',50, ...
    'NoiseVoltageStd_V',0,'NoiseCurrentStd_A',0,'Q_Target_var',80, ...
    'WindowStart_s',.2,'WindowEnd_s',.5,'BaselineBandScale',.8, ...
    'I_THD_mean_pct',2,'P_ripple_RMS_W',10,'Q_ripple_RMS_var',10, ...
    'P_tracking_RMS_W',10,'Q_tracking_RMS_var',10,'P_MaxAbsTrackingError_W',25, ...
    'Q_Overshoot_var',0,'Q_Overshoot_pct',0, ...
    'SwitchCyclesPerLeg_Hz',4000,'SwitchLegA_Hz',4000,'SwitchLegB_Hz',4000, ...
    'SwitchLegC_Hz',4000,'SwitchTransitionsPerLeg_per_s',8000, ...
    'VoltageVerified',true,'ReferencesVerified',true,'NoiseLevelVerified',true,'WindowScreenOK',true);
end
