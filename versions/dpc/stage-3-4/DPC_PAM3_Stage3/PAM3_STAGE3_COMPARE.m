function c=PAM3_STAGE3_COMPARE(b,a,cfg,noiseMatched)
% b: frozen reference, a: proposed. Negative change means a smaller metric.
keys={'I_THD_mean_pct','P_ripple_RMS_W','Q_ripple_RMS_var', ...
    'P_tracking_RMS_W','Q_tracking_RMS_var','P_MaxAbsTrackingError_W', ...
    'Q_Overshoot_var','Q_Overshoot_pct','SwitchCyclesPerLeg_Hz', ...
    'SwitchLegA_Hz','SwitchLegB_Hz','SwitchLegC_Hz','SwitchTransitionsPerLeg_per_s'};
labels={'THD','P_Ripple','Q_Ripple','P_Tracking','Q_Tracking','P_PeakError', ...
    'Q_Overshoot_var','Q_Overshoot_pct','Switching','Switch_A','Switch_B','Switch_C','Density'};
c.Case=b.Case;c.Scenario=b.Scenario;c.L_mH=b.L_mH;c.Seed=b.Seed;
c.Va_Target_RMS_V=b.Va_Target_RMS_V;c.Vb_Target_RMS_V=b.Vb_Target_RMS_V;
c.Vc_Target_RMS_V=b.Vc_Target_RMS_V;
c.NoiseVoltageStd_V=b.NoiseVoltageStd_V;c.NoiseCurrentStd_A=b.NoiseCurrentStd_A;
c.Q_Target_var=b.Q_Target_var;c.WindowStart_s=b.WindowStart_s;c.WindowEnd_s=b.WindowEnd_s;
c.BaselineBandScale=b.BaselineBandScale;
for k=1:numel(keys)
    label=labels{k};before=b.(keys{k});after=a.(keys{k});
    c.(['Baseline_' label])=before;c.(['Proposed_' label])=after;
    c.([label '_Change_pct'])=relative_change(before,after);
end
c.Q_Overshoot_Change_pp=a.Q_Overshoot_pct-b.Q_Overshoot_pct;
switchDelta=abs([c.Switching_Change_pct c.Switch_A_Change_pct ...
    c.Switch_B_Change_pct c.Switch_C_Change_pct]);
if all(isfinite(switchDelta))
    c.MaxSwitchingMismatch_pct=max(switchDelta);
else
    c.MaxSwitchingMismatch_pct=NaN;
end
c.SwitchingComparable=isfinite(c.MaxSwitchingMismatch_pct) && ...
    c.MaxSwitchingMismatch_pct<=100*cfg.switchingToleranceFraction;
c.NoiseMatchedExact=noiseMatched;
c.InputsVerified=b.VoltageVerified && a.VoltageVerified && ...
    b.ReferencesVerified && a.ReferencesVerified && noiseMatched && ...
    b.NoiseLevelVerified && a.NoiseLevelVerified;
c.WindowScreenBothOK=b.WindowScreenOK && a.WindowScreenOK;
end

function pct=relative_change(before,after)
if isfinite(before) && before>1e-12 && isfinite(after)
    pct=100*(after-before)/before;
else
    pct=NaN;
end
end
