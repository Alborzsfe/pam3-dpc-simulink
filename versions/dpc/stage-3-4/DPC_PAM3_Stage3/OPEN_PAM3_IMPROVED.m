function model=OPEN_PAM3_IMPROVED()
cfg=pam3_study_config();
model=BUILD_PAM3_STUDY_MODEL('predictive',[0 0],cfg.cleanSeed,cfg);
open_system(model);open_system([model '/MATLAB Function3']);
fprintf('Compiled: %s. Clean grid; causal model-assisted detector; DC measurement input 5.\n',model);
fprintf('Run RUN_PAM3_STUDY for compatibility, clean/noisy numerical comparison.\n');
end
