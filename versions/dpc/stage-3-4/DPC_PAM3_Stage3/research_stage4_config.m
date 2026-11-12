function [cfg,cases,variants]=research_stage4_config(mode)
% Same plant, disturbances, references and frozen baseline as stage 3.
if nargin<1,mode='full';end
assert(ismember(string(mode),["full","ablation","final_point","binary_points","binary_rematch"]), ...
    'PAM3Full:Mode','Use full, ablation, final_point, binary_points, or binary_rematch.');
[cfg,cases]=research_stage3_config();
cfg.shortBuildPaths=true;
cfg.fullFeatures=pam3_full_feature_config();
names={'observer_only','full'};
flags=[0 0 0;1 1 1];
if strcmp(mode,'ablation')
    names={'observer_only','adaptive_only','confidence_only','persistence_only','full'};
    flags=[0 0 0;1 0 0;0 1 0;0 0 1;1 1 1];
elseif ismember(string(mode),["binary_points","binary_rematch"])
    requested={'S2_A40_noise','S3_Q_plus80','S2_A30_noise','S2_A40_noise'};
    [ok,idx]=ismember(requested,{cases.Name});assert(all(ok));
    cases=cases(idx);
    cases(1).Seeds=321;cases(2).Seeds=321;cases(3).Seeds=987;
    cases(4).Seeds=[1357 2468 3579];
    cfg.binaryCaseInductances_mH=[10 10 15 15];
    cfg.binaryRefineBands=strcmp(mode,'binary_rematch');
    cfg.binaryMaxBandTrials=5;
    if cfg.binaryRefineBands,cfg.binaryMaxBandTrials=18;end
    names={'observer_only'};flags=[0 0 0];
elseif strcmp(mode,'final_point')
    cases=cases(strcmp({cases.Name},'S2_A40_noise'));
    assert(isscalar(cases),'PAM3Full:FinalPoint','Expected one frozen final point.');
    cases.Seeds=[1357 2468 3579]; % Held out from Stage 4 point selection.
    names={'observer_only'};flags=[0 0 0];
end
variants=repmat(struct('Name','','Method','','Features',cfg.fullFeatures),1,numel(names));
for k=1:numel(names)
    variants(k).Name=names{k};variants(k).Method='predictive_full';
    if k==1,variants(k).Method='predictive';end
    f=cfg.fullFeatures;
    f.adaptiveBand=logical(flags(k,1));f.confidenceGate=logical(flags(k,2));
    f.persistence=logical(flags(k,3));variants(k).Features=f;
end
end
