function [metrics,pairs,dynamics]=RUN_RESEARCH_STAGE2(mode)
% Native Simulink research suite. 'matched' = clean + existing sensor noise;
% 'all' additionally evaluates noise levels, 3/5% grid THD and independent steps.
if nargin<1,mode='all';end
assert(ismember(string(mode),["matched","all"]),'PAM3Study:Mode','Use matched or all.');
root=fileparts(mfilename('fullpath'));addpath(root);
cfg0=research_stage2_config();
assert(~ismember(cfg0.calibrationSeed,cfg0.seeds),'PAM3Study:Seeds','Calibration seed must be independent.');
VALIDATE_PAM3_IMPROVED();VALIDATE_SENSOR_NOISE();VALIDATE_STUDY_CONNECTIONS();
VALIDATE_RESEARCH_STAGE2();
folder=fullfile(root,'research_results',['run_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);
assert(~isfolder(folder),'PAM3Study:Folder','Output folder already exists.');mkdir(folder);
save(fullfile(folder,'study_config.mat'),'cfg0','mode');
mr={};pr={};dr={};
metrics=table();pairs=table();dynamics=table();
verdict.StudyComplete=false;verdict.Message='Calibration/evaluation has not completed.';
write_verdict(folder,verdict);
for fs=cfg0.researchFrequencies(:)'
 for L=cfg0.researchInductances(:)'
  cfg=cfg0;cfg.Ts=1/fs;cfg.modelL=L;
  scenario=sprintf('%gkHz_%gmH',fs/1000,L*1000);
  fprintf('\nResearch scenario: %s\n',scenario);
  scenarioFolder=fullfile(folder,scenario);mkdir(scenarioFolder);
  calibrationFolder=fullfile(scenarioFolder,'calibration');mkdir(calibrationFolder);
  cfg.modelPrefix='DPC3_calibration_';
  calibration=PAM3_MATCH_SWITCHING(cfg,calibrationFolder);
  band=calibration.BandScale;
  evaluate_case('clean',[0 0],cfg.cleanSeed,0,'fixed_power');
  levels=cfg.noiseStd;
  if strcmp(mode,'all'),levels=cfg.noiseLevels;end
  for level=1:size(levels,1)
   for seed=cfg.seeds
    name=sprintf('sensor_nv%g_ni%g_seed%d',levels(level,:),seed);
    evaluate_case(name,levels(level,:),seed,0,'fixed_power');
   end
  end
  if strcmp(mode,'all')
   for thd=cfg.sourceTHDLevels
    evaluate_case(sprintf('grid_THD%g',100*thd),[0 0],cfg.cleanSeed,thd,'fixed_power');
   end
   evaluate_case('P_step_60_to_100pct',[0 0],cfg.cleanSeed,0,'stepP');
   evaluate_case('Q_step_independent',[0 0],cfg.cleanSeed,0,'stepQ');
  end
 end
end
fprintf('\nResearch results: %s\n',folder);
    function evaluate_case(caseName,noise,seed,thd,referenceMode)
        fprintf('\nResearch case: %s / %s\n',scenario,caseName);
        c=cfg;c.sourceTHD=thd;c.referenceMode=referenceMode;
        dynamic=ismember(referenceMode,{'stepP','stepQ'});
        if dynamic
            c.stopTime=c.dynamicStopTime;c.window=c.dynamicWindow;
            if strcmp(referenceMode,'stepQ'),c.Pbefore=c.Pnom;c.Pafter=c.Pnom;
            else,c.Qbefore=0;c.Qafter=0;end
        end
        caseFolder=fullfile(scenarioFolder,caseName);mkdir(caseFolder);
        methods={'baseline','baseline','predictive'};
        roles={'original_baseline','matched_baseline','proposed'};
        r=cell(1,3);
        for kk=1:3
            c.role=roles{kk};c.baselineBandScale=1;
            if kk==2,c.baselineBandScale=band;end
            c.modelPrefix=['DPC3_' referenceMode '_' roles{kk} '_'];
            c.outputFolder=fullfile(caseFolder,roles{kk});
            r{kk}=PAM3_STUDY_CASE(methods{kk},noise,seed,c);
            m=r{kk}.metrics;m.Scenario=string(scenario);m.Case=string(caseName);
            mr{end+1,1}=m; %#ok<AGROW>
            if dynamic
                if strcmp(referenceMode,'stepP'),axisName='P';else,axisName='Q';end
                d=PAM3_DYNAMIC_METRICS(r{kk}.raw,c,axisName);
                d.Scenario=string(scenario);d.Case=string(caseName);d.Role=string(roles{kk});
                d.Axis=string(axisName);dr{end+1,1}=d; %#ok<AGROW>
            end
        end
        % Verify actual injected sequences for every pair, including zeros.
        noiseMatched=true;referencesMatched=true;
        sampleTimes=(0:round(c.stopTime/c.Ts))'*c.Ts;
        sampleTimes(end)=c.stopTime;
        for kk=1:2
            for field={'NoiseV','NoiseI'}
                a=r{kk}.raw.(field{1});b=r{3}.raw.(field{1});
                noiseMatched=noiseMatched && isequal(a.time,b.time) && ...
                    isequal(a.signals.values,b.signals.values);
            end
            for field={'Pref','Qref'}
                referencesMatched=referencesMatched && isequal( ...
                    PAM3_SAMPLE(r{kk}.raw.(field{1}),sampleTimes), ...
                    PAM3_SAMPLE(r{3}.raw.(field{1}),sampleTimes));
            end
        end
        for kk=1:2
            b=r{kk}.metrics;a=r{3}.metrics;
            pair=PAM3_COMPARE_CASES(b,a,c);
            pair.P_Tracking_Change_pct=100*(a.P_tracking_RMS_W/max(b.P_tracking_RMS_W,eps)-1);
            pair.Q_Tracking_Change_pct=100*(a.Q_tracking_RMS_var/max(b.Q_tracking_RMS_var,eps)-1);
            pair.QualityAcceptable=pair.QualityAcceptable && pair.Q_Tracking_Change_pct<=5;
            pair.QualityUseful=pair.QualityUseful && pair.QualityAcceptable;
            pair.UsefulAtComparableSwitching=pair.QualityUseful && pair.SwitchingComparable && noiseMatched && referencesMatched;
            pair.Scenario=string(scenario);pair.Case=string(caseName);
            pair.BaselineRole=string(roles{kk});pair.BaselineBandScale=b.BaselineBandScale;
            pair.NoiseMatchedExact=noiseMatched;pair.SteadyCase=~dynamic;
            pair.ReferencesMatchedExact=referencesMatched;
            pair.P_DecisionChanges_Change=a.P_DecisionChanges-b.P_DecisionChanges;
            pair.Q_DecisionChanges_Change=a.Q_DecisionChanges-b.Q_DecisionChanges;
            pair.PCCVoltageTHD_pct=a.V_THD_mean_pct;
            pair.SourceTHDTarget_pct=100*thd;
            pair.PCCDistortionVerified=abs(a.V_THD_mean_pct-100*thd)<.25;
            pair.UsefulAtComparableSwitching=pair.UsefulAtComparableSwitching && pair.PCCDistortionVerified;
            pr{end+1,1}=pair; %#ok<AGROW>
        end
        % Preserve tables before plotting, even if a figure export fails.
        metrics=struct2table(vertcat(mr{:}));pairs=struct2table(vertcat(pr{:}));
        writetable(metrics,fullfile(folder,'research_metrics.csv'));
        writetable(pairs,fullfile(folder,'research_pairs.csv'));
        if ~isempty(dr)
            dynamics=struct2table(vertcat(dr{:}));
            writetable(dynamics,fullfile(folder,'dynamic_metrics.csv'));
        end
        save(fullfile(folder,'research_summary.mat'),'metrics','pairs','dynamics','cfg0','mode');
        selected=pairs.BaselineRole=="matched_baseline" & pairs.SteadyCase;
        verdict.EvaluatedSteadyMatchedPairs=sum(selected);
        verdict.SwitchingComparablePairs=sum(pairs.SwitchingComparable(selected));
        verdict.UsefulAtComparableSwitchingPairs=sum(pairs.UsefulAtComparableSwitching(selected));
        verdict.AllCompletedSteadyPairsUseful=all(pairs.UsefulAtComparableSwitching(selected));
        verdict.StudyComplete=false;
        verdict.Message='Partial checkpoint. Counts describe completed cases only; inspect each row.';
        write_verdict(folder,verdict);
        try
            PAM3_RESEARCH_PLOTS(r,c,caseFolder);
        catch plottingProblem
            warning('PAM3Study:Plot','Data saved, but plot export failed: %s',plottingProblem.message);
            fid=fopen(fullfile(caseFolder,'plot_export_error.txt'),'w');
            if fid>=0,fprintf(fid,'%s',getReport(plottingProblem));fclose(fid);end
        end
    end
% A complete flag is written only after all requested scenarios finish.
selected=pairs.BaselineRole=="matched_baseline" & pairs.SteadyCase;
verdict.EvaluatedSteadyMatchedPairs=sum(selected);
verdict.SwitchingComparablePairs=sum(pairs.SwitchingComparable(selected));
verdict.UsefulAtComparableSwitchingPairs=sum(pairs.UsefulAtComparableSwitching(selected));
verdict.AllCompletedSteadyPairsUseful=all(pairs.UsefulAtComparableSwitching(selected));
verdict.StudyComplete=true;
verdict.Message='Finite cases only. Calibration was switching-only; band frozen before held-out noisy tests. Unmatched cases do not establish equal-switching superiority.';
write_verdict(folder,verdict);
end
function write_verdict(folder,verdict)
fid=fopen(fullfile(folder,'research_verdict.json'),'w');assert(fid>=0);
fwrite(fid,jsonencode(verdict,PrettyPrint=true),'char');fclose(fid);
end
