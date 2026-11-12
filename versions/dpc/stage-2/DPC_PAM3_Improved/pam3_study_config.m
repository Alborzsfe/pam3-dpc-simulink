function cfg = pam3_study_config()
% All choices are explicit. No gains are selected by looking at test results.
cfg.Ts=1/40000; cfg.e=50; cfg.stopTime=0.5;
cfg.fundamentalHz=50; cfg.window=[0.30 0.40]; cfg.maxHarmonic=40;
cfg.adaptiveGain=0.50; cfg.noiseFloorPu=0.015;
% Measurement noise at vabc/iabc BEFORE power calculation and sector choice.
% Engineering test levels, NOT measured sensor specifications:
% [volts RMS per phase, amperes RMS per phase] of zero-mean added noise.
cfg.noiseStd=[0.5 0.05]; cfg.seeds=[321 654 987];
cfg.cleanSeed=321;
cfg.modelR=0.2; cfg.modelL=15e-3; cfg.maxObserverBlend=0.8;
% Engineering comparison gates, NOT guarantees or standards.
cfg.allowedWorseningFraction=0.05;
cfg.meanPowerToleranceW=8; cfg.meanQToleranceVar=8;
cfg.vdcToleranceV=3; cfg.minUsefulImprovementFraction=0.05;
% Approximate equality of actual switching counts, NOT sampling frequency.
cfg.switchingToleranceFraction=0.05;
end
