function summary=RUN_PROFESSOR_SCENARIOS()
% Full factorial: both sampling frequencies at BOTH filter inductances.
% Each scenario runs the complete existing clean/noisy comparison (13 runs).
root=fileparts(mfilename('fullpath'));
batchFolder=fullfile(root,'scenario_results', ...
    ['run_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);
assert(~isfolder(batchFolder),'PAM3Study:ExistingBatch', ...
    'Result folder already exists; rerun to obtain a new timestamp.');
[ok,msg]=mkdir(batchFolder);assert(ok,'PAM3Study:OutputFolder','%s',msg);
names={'20kHz_10mH','20kHz_15mH','40kHz_10mH','40kHz_15mH'};
frequencies=[20000 20000 40000 40000];inductances=[10e-3 15e-3 10e-3 15e-3];
summary=cell(1,4);allMetrics=cell(1,4);
for k=1:4
    cfg=pam3_study_config();
    cfg.Ts=1/frequencies(k);cfg.modelL=inductances(k);
    cfg.outputFolder=fullfile(batchFolder,names{k});
    mkdir(cfg.outputFolder);
    save(fullfile(cfg.outputFolder,'scenario_config.mat'),'cfg');
    fprintf('\nScenario %s: fs=%g Hz, L=%g H\n', ...
        names{k},1/cfg.Ts,cfg.modelL);
    [T,~,verdict]=RUN_PAM3_STUDY(cfg);
    allMetrics{k}=T;
    writetable(vertcat(allMetrics{1:k}),fullfile(batchFolder,'all_scenarios_metrics.csv'));
    summary{k}=struct('Name',names{k},'Folder',cfg.outputFolder, ...
        'SamplingFrequency_Hz',1/cfg.Ts,'FilterInductance_H',cfg.modelL, ...
        'Metrics',T,'Verdict',verdict);
    save(fullfile(batchFolder,'scenario_summary.mat'),'summary');
end
fprintf('\nAll FOUR scenarios saved in: %s\n',batchFolder);
end
