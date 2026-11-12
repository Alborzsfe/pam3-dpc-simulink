function model=OPEN_PAM3_COMPATIBLE()
% Exact decision-law compatibility: adaptation gain is zero.
cfg=pam3_study_config();
model=BUILD_PAM3_STUDY_MODEL('compatible',[0 0],cfg.cleanSeed,cfg);
open_system(model);open_system([model '/MATLAB Function3']);
fprintf('Compiled compatible mode. This is a reference check, NOT proof of improvement.\n');
end
