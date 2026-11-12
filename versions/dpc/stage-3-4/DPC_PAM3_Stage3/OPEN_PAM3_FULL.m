function model=OPEN_PAM3_FULL(LmH)
% Build and open the proposed full-feature variant; does not run a simulation.
if nargin<1,LmH=15;end
assert(ismember(LmH,[10 15]),'PAM3Full:L','Use 10 or 15 mH.');
root=fileparts(mfilename('fullpath'));addpath(root);
[cfg,~,~]=research_stage4_config('full');
cfg.modelL=LmH/1000;cfg.sourcePhaseScale=[1 1 1];
cfg.modelPrefix='DPC4_preview_';cfg.role='full';
PAM3_SHORT_BUILD_PATHS(cfg);
model=BUILD_PAM3_STUDY_MODEL('predictive_full',cfg.noiseStd,cfg.cleanSeed,cfg);
PAM3_STUDY_INSTRUMENT(model,cfg);save_system(model);open_system(model);
end
