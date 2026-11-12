function p=PAM3_FULL_FEATURE_VECTOR(f)
% Fixed-size numeric parameter vector for MATLAB Function code generation.
names={'adaptiveBand','confidenceGate','persistence','hEnterPu','hExitPu', ...
    'bandNoiseGain','maxExtraBandPu','noiseFloorPu','noiseTimeConstant_s', ...
    'bandTimeConstant_s','startupWarmup_s','confidenceMarginSigma', ...
    'sigmaFloorPu','persistenceSamples','emergencyErrorPu','referenceGuard_s', ...
    'secondDifferenceClipPu','sigmaLimitPu'};
p=zeros(18,1);
for k=1:numel(names)
    assert(isfield(f,names{k}),'PAM3Full:Parameter','Missing fullFeatures.%s.',names{k});
    x=f.(names{k});
    validateattributes(x,{'numeric','logical'},{'real','finite','scalar','nonnegative'});
    p(k)=double(x);
end
assert(all(ismember(p(1:3),[0 1])),'PAM3Full:Flags','Feature flags must be 0 or 1.');
assert(p(4)>p(5) && p(5)>0,'PAM3Full:Bands','Require hEnterPu > hExitPu > 0.');
assert(all(p([9 10 13 15 17 18])>0),'PAM3Full:Parameters','Time constants and scale limits must be positive.');
assert(p(14)>=1 && p(14)==round(p(14)) && p(14)<=20, ...
    'PAM3Full:Persistence','persistenceSamples must be an integer in 1..20.');
assert(p(15)>p(4)+p(7),'PAM3Full:Bypass','Emergency threshold must exceed the widest entry band.');
end
