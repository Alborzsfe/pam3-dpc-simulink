function d=PAM3_DYNAMIC_METRICS(raw,cfg,axisName)
% Measured response + operational definitions. No Control System Toolbox.
t=(0:round(cfg.stopTime/cfg.Ts))'*cfg.Ts;
t(end)=cfg.stopTime;
y=PAM3_SAMPLE(raw.(axisName),t);ref=PAM3_SAMPLE(raw.([axisName 'ref']),t);
post=t>=cfg.stepTime;tp=t(post)-cfg.stepTime;yp=y(post);rp=ref(post);
pre=t>=cfg.dynamicPreWindow(1) & t<cfg.dynamicPreWindow(2);
y0=mean(y(pre));target=rp(end);requestedStep=rp(end)-ref(find(t<cfg.stepTime,1,'last'));
assert(abs(requestedStep)>0,'PAM3Study:DynamicStep','No reference step.');
direction=sign(requestedStep);amplitude=abs(requestedStep);
progress=direction*(yp-y0);
i10=find(progress>=.1*amplitude,1);i90=find(progress>=.9*amplitude,1);
d.RiseTime10to90_s=NaN;d.DelayTo10pct_s=NaN;
if ~isempty(i10),d.DelayTo10pct_s=tp(i10);end
if ~isempty(i10) && ~isempty(i90),d.RiseTime10to90_s=max(0,tp(i90)-tp(i10));end
d.PeakOvershoot_pct=100*max(0,max(direction*(yp-target)))/amplitude;
d.PeakAbsError=max(abs(yp-rp));d.PostStepTrackingRMS=sqrt(mean((yp-rp).^2));
d.IntegralAbsError=trapz(tp,abs(yp-rp));
tail=tp>=tp(end)-cfg.dynamicTailDuration;
d.FinalMeanError=mean(yp(tail)-rp(tail));
d.FinalErrorRMS=sqrt(mean((yp(tail)-rp(tail)).^2));
% Instantaneous settling: every remaining sample must stay within 2% of step
% amplitude, with at least 10 ms observation after the crossing.
inside=abs(yp-rp)<=cfg.settlingBandFraction*amplitude;
lastOutside=find(~inside,1,'last');
if isempty(lastOutside),index=1;else,index=lastOutside+1;end
d.InstantaneousSettlingTime_s=NaN;
if index<=numel(tp) && tp(end)-tp(index)>=cfg.settlingDwell
    d.InstantaneousSettlingTime_s=tp(index);
end
% Separate 1 ms causal moving mean. Filtering delay remains INCLUDED; this
% metric never replaces instantaneous ripple, overshoot or tracking error.
smooth=movmean(y,[max(1,round(.001/cfg.Ts))-1 0]);sm=smooth(post);
inside=abs(sm-rp)<=cfg.settlingBandFraction*amplitude;
lastOutside=find(~inside,1,'last');
if isempty(lastOutside),index=1;else,index=lastOutside+1;end
d.Mean1msSettlingTime_s=NaN;
if index<=numel(tp) && tp(end)-tp(index)>=cfg.settlingDwell
    d.Mean1msSettlingTime_s=tp(index);
end
d.PreStepMean=y0;d.FinalReference=target;d.RequestedStep=requestedStep;
d.VdcMin_V=min(PAM3_SAMPLE(raw.Vdc,t));d.VdcMax_V=max(PAM3_SAMPLE(raw.Vdc,t));
d.PreStepMeanError=mean(y(pre)-ref(pre));
end
