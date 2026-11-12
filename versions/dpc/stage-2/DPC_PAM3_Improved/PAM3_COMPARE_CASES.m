function c=PAM3_COMPARE_CASES(b,a,cfg)
% Transparent pairwise gates. Switching equality is an engineering tolerance,
% not a claim about switching losses or mathematical controller equivalence.
c.Method=a.Method;c.Seed=a.Seed;
c.SamplingFrequency_Hz=a.SamplingFrequency_Hz;c.FilterInductance_H=a.FilterInductance_H;
c.NoiseVoltageStd_V=a.NoiseVoltageStd_V;c.NoiseCurrentStd_A=a.NoiseCurrentStd_A;
c.THD_Change_pct=100*(a.I_THD_mean_pct/max(b.I_THD_mean_pct,eps)-1);
c.P_Ripple_Change_pct=100*(a.P_ripple_RMS_W/max(b.P_ripple_RMS_W,eps)-1);
c.Q_Ripple_Change_pct=100*(a.Q_ripple_RMS_var/max(b.Q_ripple_RMS_var,eps)-1);
c.Switching_Change_pct=100*(a.SwitchCyclesPerLeg_Hz/max(b.SwitchCyclesPerLeg_Hz,eps)-1);
legs={'SwitchLegA_Hz','SwitchLegB_Hz','SwitchLegC_Hz','SwitchCyclesPerLeg_Hz'};
relative=zeros(1,numel(legs));
for k=1:numel(legs)
    relative(k)=abs(a.(legs{k})-b.(legs{k}))/max(b.(legs{k}),eps);
end
c.MaxSwitchingMismatch_pct=100*max(relative);
c.SwitchingComparable=all(relative<=cfg.switchingToleranceFraction);
fields={'P_ripple_RMS_W','Q_ripple_RMS_var','Ia_THD_pct','Ib_THD_pct','Ic_THD_pct', ...
    'Ia_THDN_pct','Ib_THDN_pct','Ic_THDN_pct'};
ratios=zeros(1,numel(fields));
for k=1:numel(fields),ratios(k)=a.(fields{k})/max(b.(fields{k}),eps);end
c.QualityAcceptable=all(ratios<=1+cfg.allowedWorseningFraction) && ...
    abs(a.P_mean_W-b.P_mean_W)<=cfg.meanPowerToleranceW && ...
    abs(a.Q_mean_var)<=max(cfg.meanQToleranceVar,abs(b.Q_mean_var)+2) && ...
    abs(a.Vdc_mean_V-b.Vdc_mean_V)<=cfg.vdcToleranceV && ...
    a.P_tracking_RMS_W<=1.05*max(b.P_tracking_RMS_W,eps) && ...
    a.WindowScreenOK && b.WindowScreenOK;
c.QualityUseful=c.QualityAcceptable && any([c.THD_Change_pct, ...
    c.P_Ripple_Change_pct,c.Q_Ripple_Change_pct]<-100*cfg.minUsefulImprovementFraction);
c.UsefulAtComparableSwitching=c.QualityUseful && c.SwitchingComparable;
end
