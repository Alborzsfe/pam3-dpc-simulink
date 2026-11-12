function o=PAM3_STAGE3_OBSERVATIONS(raw,cfg)
% Independent input checks and step metrics from the physical log, not the noisy sensor.
n=round(diff(cfg.window)/cfg.Ts);
t=cfg.window(1)+((0:n-1)'+.5)*cfg.Ts;
v=PAM3_SAMPLE(raw.V,t);
assert(size(v,2)==3 && all(isfinite(v(:))),'PAM3Stage3:Vabc','Expected finite physical Vabc.');
rmsV=sqrt(mean(v.^2,1));
fund=2/n*sum(v.*exp(-1i*2*pi*cfg.fundamentalHz*t),1);
relPhase=angle(fund(2:3)./fund(1))*180/pi;
expectedV=cfg.e*cfg.sourcePhaseScale(:)';
o.Va_RMS_V=rmsV(1);o.Vb_RMS_V=rmsV(2);o.Vc_RMS_V=rmsV(3);
o.Vb_RelativeToA_deg=relPhase(1);o.Vc_RelativeToA_deg=relPhase(2);
o.VoltageVerified=all(abs(rmsV-expectedV)<=cfg.voltageTolerance_V) && ...
    all(abs(relPhase-[-120 120])<=cfg.phaseTolerance_deg);
% Verify before and after the step, including the first interval after 0.2 s.
nAll=round(cfg.stopTime/cfg.Ts);
ta=((0:nAll-1)'+.5)*cfg.Ts;
pref=PAM3_SAMPLE(raw.Pref,ta,'Pref');qref=PAM3_SAMPLE(raw.Qref,ta,'Qref');
qExpected=zeros(size(ta));
if strcmp(cfg.referenceMode,'stepQ'),qExpected(ta>=cfg.stepTime)=cfg.Qafter;end
o.ReferencesVerified=all(abs(pref-cfg.Pnom)<1e-9) && all(abs(qref-qExpected)<1e-9);
o.Q_Overshoot_var=NaN;o.Q_Overshoot_pct=NaN;
o.P_MaxAbsTrackingError_W=NaN;
if strcmp(cfg.referenceMode,'stepQ')
    p=PAM3_SAMPLE(raw.P,t);q=PAM3_SAMPLE(raw.Q,t);
    amplitude=abs(cfg.Qafter-cfg.Qbefore);
    assert(amplitude>0,'PAM3Stage3:Step','Reactive step magnitude must be positive.');
    direction=sign(cfg.Qafter-cfg.Qbefore);
    o.Q_Overshoot_var=max(0,max(direction*(q-cfg.Qafter)));
    o.Q_Overshoot_pct=100*o.Q_Overshoot_var/amplitude;
    o.P_MaxAbsTrackingError_W=max(abs(p-cfg.Pnom));
end
end
