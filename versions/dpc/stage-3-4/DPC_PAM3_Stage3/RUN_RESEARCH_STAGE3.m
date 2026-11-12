function [metrics,pairs,summary,folder]=RUN_RESEARCH_STAGE3(inductances_mH)
% Run the professor's three follow-up experiments with frozen controllers.
% Default: 15 and 10 mH. RUN_RESEARCH_STAGE3(15) runs just the 15 mH cases.
root=fileparts(mfilename('fullpath'));addpath(root);
[cfg0,cases]=research_stage3_config();
if nargin<1,inductances_mH=1000*cfg0.researchInductances;end
validateattributes(inductances_mH,{'numeric'},{'real','finite','vector','nonempty'});
inductances_mH=unique(inductances_mH(:)','stable');
[valid,indices]=ismember(inductances_mH,1000*cfg0.researchInductances);
assert(all(valid),'PAM3Stage3:Inductance','Use 10 mH, 15 mH, or both.');
VALIDATE_RESEARCH_STAGE3();
assert(exist('load_system','file')~=0 || exist('load_system','builtin')~=0, ...
    'PAM3Stage3:Simulink','This study requires MATLAB with Simulink and Specialized Power Systems.');
load_system('powerlib');
stamp=datestr(now,'yyyymmdd_HHMMSS_FFF');
folder=fullfile(root,'research_stage3_results',['run_' stamp]);
assert(~isfolder(folder),'PAM3Stage3:Output','Output folder already exists.');
mkdir(folder);save(fullfile(folder,'stage3_config.mat'),'cfg0','cases','inductances_mH');
metrics=table();pairs=table();summary=table();
mRows={};pRows={};
status=struct('StudyComplete',false,'CompletedPairs',0, ...
    'ExpectedPairs',numel(indices)*sum(arrayfun(@(s)numel(s.Seeds),cases)), ...
    'InputVerifiedPairs',0,'SwitchingComparablePairs',0, ...
    'VerifiedAndComparablePairs',0,'PlotErrors',0,'LastError','');
write_status(folder,status);
try
    for index=indices
        for j=1:numel(cases)
            s=cases(j);
            for seed=s.Seeds
                cfg=cfg0;
                cfg.modelL=cfg0.researchInductances(index);
                cfg.sourcePhaseScale=[s.PhaseA_RMS_V/cfg.e 1 1];
                isStep=s.Qafter_var~=0;
                if isStep
                    cfg.referenceMode='stepQ';
                    cfg.Qafter=s.Qafter_var;
                    cfg.window=cfg.stepAnalysisWindow;
                end
                tag=sprintf('%02dmH_%s_seed%d',round(1000*cfg.modelL),s.Name,seed);
                caseFolder=fullfile(folder,tag);mkdir(caseFolder);
                cfg.modelPrefix=sprintf('DPC3_%s_%02d_',stamp,status.CompletedPairs+1);
                fprintf('\nStage 3: %s\n',tag);
                r=cell(1,2);m=cell(1,2);
                methods={'baseline','predictive'};roles={'matched_baseline','proposed'};
                for k=1:2
                    c=cfg;c.role=roles{k};c.baselineBandScale=1;
                    if k==1,c.baselineBandScale=cfg0.frozenBaselineBands(index);end
                    c.outputFolder=fullfile(caseFolder,roles{k});
                    r{k}=PAM3_STUDY_CASE(methods{k},s.NoiseStd,seed,c);
                    m{k}=attach_observations(r{k},c,s);
                    % Only close this run's generated model; preserve raw logs.
                    close_system(r{k}.model,0);
                end
                noiseMatched=same_noise(r{1}.raw,r{2}.raw);
                p=PAM3_STAGE3_COMPARE(m{1},m{2},cfg,noiseMatched);
                mRows(end+1:end+2,1)=m(:); %#ok<AGROW>
                pRows{end+1,1}=p; %#ok<AGROW>
                metrics=struct2table(vertcat(mRows{:}));
                pairs=struct2table(vertcat(pRows{:}));
                summary=struct2table(summarize(vertcat(pRows{:})));
                writetable(metrics,fullfile(folder,'stage3_metrics.csv'));
                writetable(pairs,fullfile(folder,'stage3_pairs.csv'));
                writetable(summary,fullfile(folder,'stage3_summary.csv'));
                status.CompletedPairs=height(pairs);
                status.InputVerifiedPairs=sum(pairs.InputsVerified);
                status.SwitchingComparablePairs=sum(pairs.SwitchingComparable);
                status.VerifiedAndComparablePairs=sum(pairs.InputsVerified & pairs.SwitchingComparable);
                write_status(folder,status);
                if ~p.InputsVerified
                    warning('PAM3Stage3:Inputs','Input check failed for %s. Inspect stage3_metrics.csv.',tag);
                end
                if ~p.SwitchingComparable
                    fprintf('Switching is outside the comparison tolerance: max mismatch %.2f%%.\n', ...
                        p.MaxSwitchingMismatch_pct);
                end
                if isStep
                    try
                        PAM3_STAGE3_PLOT_STEP(r,cfg,caseFolder);
                    catch plotProblem
                        status.PlotErrors=status.PlotErrors+1;
                        write_status(folder,status);
                        write_text(fullfile(caseFolder,'plot_error.txt'),getReport(plotProblem));
                        warning('PAM3Stage3:Plot','Metrics saved, but plot export failed for %s.',tag);
                    end
                end
            end
        end
    end
catch problem
    status.LastError=problem.message;write_status(folder,status);rethrow(problem);
end
status.StudyComplete=status.CompletedPairs==status.ExpectedPairs;
write_status(folder,status);
fprintf('\nStage 3 complete: %d pairs, %d verified and within switching tolerance.\n%s\n', ...
    status.CompletedPairs,status.VerifiedAndComparablePairs,folder);
end

function m=attach_observations(run,cfg,spec)
m=run.metrics;
o=PAM3_STAGE3_OBSERVATIONS(run.raw,cfg);
names=fieldnames(o);
for k=1:numel(names),m.(names{k})=o.(names{k});end
m.Case=string(spec.Name);m.Scenario=string(spec.Scenario);
m.L_mH=round(1000*cfg.modelL);
m.Va_Target_RMS_V=spec.PhaseA_RMS_V;m.Vb_Target_RMS_V=cfg.e;m.Vc_Target_RMS_V=cfg.e;
m.Q_Target_var=spec.Qafter_var;
m.WindowStart_s=cfg.window(1);m.WindowEnd_s=cfg.window(2);
m.SwitchTransitionsPerLeg_per_s=2*m.SwitchCyclesPerLeg_Hz;
actual=[m.InjectedNoiseVoltage_RMS_V m.InjectedNoiseCurrent_RMS_A];
goal=spec.NoiseStd;
if all(goal==0)
    m.NoiseLevelVerified=all(actual==0);
else
    m.NoiseLevelVerified=all(abs(actual-goal)<=cfg.noiseRmsToleranceFraction*goal);
end
end

function equal=same_noise(a,b)
equal=true;
for key={'NoiseV','NoiseI'}
    x=a.(key{1});y=b.(key{1});
    equal=equal && isequal(x.time,y.time) && isequal(x.signals.values,y.signals.values);
end
end

function out=summarize(p)
% Mean each method across repeated seeds, then calculate the relative change.
% Keep per-run verification counts; a near-equal aggregate is insufficient.
out={};
fields=fieldnames(p);labels=fields(startsWith(fields,'Baseline_'));
fixed={'Case','Scenario','L_mH','Va_Target_RMS_V','Vb_Target_RMS_V', ...
    'Vc_Target_RMS_V','NoiseVoltageStd_V','NoiseCurrentStd_A','Q_Target_var', ...
    'WindowStart_s','WindowEnd_s','BaselineBandScale'};
for k=1:numel(p)
    same=([p.L_mH]==p(k).L_mH) & ([p.Case]==p(k).Case);
    if find(same,1)~=k,continue;end
    g=p(same);a=struct();
    for j=1:numel(fixed),a.(fixed{j})=p(k).(fixed{j});end
    a.PairCount=numel(g);a.InputVerifiedPairCount=sum([g.InputsVerified]);
    a.SwitchingComparablePairCount=sum([g.SwitchingComparable]);
    a.VerifiedComparablePairCount=sum([g.InputsVerified] & [g.SwitchingComparable]);
    a.AllPairsVerifiedAndComparable=a.VerifiedComparablePairCount==a.PairCount;
    err=[g.MaxSwitchingMismatch_pct];
    a.WorstSwitchingMismatch_pct=NaN;
    if all(isfinite(err)),a.WorstSwitchingMismatch_pct=max(err);end
    for j=1:numel(labels)
        bk=labels{j};suffix=bk(numel('Baseline_')+1:end);pk=['Proposed_' suffix];
        bv=mean([g.(bk)]);pv=mean([g.(pk)]);
        a.(bk)=bv;a.(pk)=pv;
        delta=NaN;
        if isfinite(bv) && isfinite(pv) && bv>1e-12,delta=100*(pv-bv)/bv;end
        a.([suffix '_Change_pct'])=delta;
    end
    a.Q_Overshoot_Change_pp=a.Proposed_Q_Overshoot_pct-a.Baseline_Q_Overshoot_pct;
    out{end+1,1}=a; %#ok<AGROW>
end
out=vertcat(out{:});
end

function write_status(folder,status)
write_text(fullfile(folder,'stage3_status.json'),jsonencode(status,'PrettyPrint',true));
end

function write_text(path,content)
fid=fopen(path,'w');
assert(fid>=0,'PAM3Stage3:File','Cannot write %s.',path);
fwrite(fid,content,'char');fclose(fid);
end
