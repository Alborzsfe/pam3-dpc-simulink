function score=PAM3_SWITCH_SCORE(baseline,proposed)
% Switching-only calibration objective. No THD/ripple/quality input is used.
fields={'SwitchLegA_Hz','SwitchLegB_Hz','SwitchLegC_Hz','SwitchCyclesPerLeg_Hz'};
score=0;
for j=1:numel(baseline)
    for k=1:numel(fields)
        b=baseline{j}.(fields{k});p=proposed{j}.(fields{k});
        score=max(score,abs(b-p)/max(b,eps));
    end
end
end
