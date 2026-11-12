function f=pam3_full_feature_config()
% Initial engineering settings, frozen before converter evaluation.
% None of these settings are claimed to reproduce a patent equation.
f.adaptiveBand=true;
f.confidenceGate=true;
f.persistence=true;
f.hEnterPu=.010;
f.hExitPu=.005;
f.bandNoiseGain=.50;
f.maxExtraBandPu=.005;
f.noiseFloorPu=.002;
f.noiseTimeConstant_s=.003;
f.bandTimeConstant_s=.002;
f.startupWarmup_s=.050;
f.confidenceMarginSigma=1.0;
f.sigmaFloorPu=.0005;
f.persistenceSamples=3;
f.emergencyErrorPu=.050;
f.referenceGuard_s=.001;
f.secondDifferenceClipPu=.060;
f.sigmaLimitPu=.025;
end
