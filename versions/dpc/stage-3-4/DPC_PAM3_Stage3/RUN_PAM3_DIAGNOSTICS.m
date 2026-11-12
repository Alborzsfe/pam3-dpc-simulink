function T=RUN_PAM3_DIAGNOSTICS()
% Actual Simulink ablations; all use the SAME clean plant and zero added noise.
% Differences between these rows, not a screenshot alone, establish causes.
root=fileparts(mfilename('fullpath'));cfg=pam3_study_config();
methods={'baseline','adc','raw','delay','legacy','adaptive','predictive'};
results=cell(numel(methods),1);
for k=1:numel(methods)
 results{k}=PAM3_STUDY_CASE(methods{k},[0 0],cfg.cleanSeed,cfg);
end
rows=cellfun(@(x)x.metrics,results,'UniformOutput',false);T=struct2table(vertcat(rows{:}));
writetable(T,fullfile(root,'results','diagnostic_ablation.csv'));
save(fullfile(root,'results','diagnostic_ablation.mat'),'results','T','cfg');disp(T);
end
