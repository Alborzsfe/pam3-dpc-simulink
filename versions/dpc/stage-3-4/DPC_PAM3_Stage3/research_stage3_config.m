function [cfg,cases]=research_stage3_config()
% Frozen settings from the stage-2 report, with only the requested test inputs changed.
cfg=research_stage2_config();
cfg.researchInductances=[15e-3 10e-3];
cfg.frozenBaselineBands=[.8 .5]; % Paired with inductances above; do not tune in stage 3.
cfg.Ts=1/40000;
cfg.e=50;cfg.sourceTHD=0;
cfg.stopTime=.5;cfg.window=[.30 .40];
cfg.Pnom=400;cfg.Pbefore=400;cfg.Pafter=400;
cfg.Qbefore=0;cfg.Qafter=0;cfg.stepTime=.20;
cfg.stepAnalysisWindow=[.20 .50];
cfg.stepPlotWindow=[.10 .50];
cfg.voltageTolerance_V=.25;
cfg.phaseTolerance_deg=1;
cfg.noiseRmsToleranceFraction=.10;
zero=[0 0];mid=[.5 .05];
cases=[ ...
    makecase('S1_A50_clean','S1_voltage_unbalance',50,zero,cfg.cleanSeed,0), ...
    makecase('S1_A40_clean','S1_voltage_unbalance',40,zero,cfg.cleanSeed,0), ...
    makecase('S1_A30_clean','S1_voltage_unbalance',30,zero,cfg.cleanSeed,0), ...
    makecase('S2_A40_noise','S2_unbalance_noise',40,mid,cfg.seeds,0), ...
    makecase('S2_A30_noise','S2_unbalance_noise',30,mid,cfg.seeds,0), ...
    makecase('S3_Q_plus80','S3_Q_step',50,zero,cfg.cleanSeed,80), ...
    makecase('S3_Q_minus80','S3_Q_step',50,zero,cfg.cleanSeed,-80)];
end

function c=makecase(name,scenario,phaseA,noise,seeds,qafter)
c=struct('Name',name,'Scenario',scenario,'PhaseA_RMS_V',phaseA, ...
    'NoiseStd',noise,'Seeds',seeds,'Qafter_var',qafter);
end
