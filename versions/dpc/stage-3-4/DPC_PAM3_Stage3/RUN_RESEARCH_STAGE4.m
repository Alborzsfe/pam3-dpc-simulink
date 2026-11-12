function [metrics,pairs,summary,folder]=RUN_RESEARCH_STAGE4(mode,inductances_mH)
% Compare the frozen DPC, original observer, and added feature variant(s).
% 'full': reference + observer_only + full.
% 'ablation': also adaptive_only, confidence_only, persistence_only.
% 'final_point': one frozen operating point with three new noise seeds.
% 'binary_rematch': bounded band search for the four unmatched 15 mH pairs.
if nargin<1,mode='full';end
root=fileparts(mfilename('fullpath'));addpath(root);
[cfg0,cases,variants]=research_stage4_config(mode);
finalPoint=strcmp(mode,'final_point');
binaryRematch=strcmp(mode,'binary_rematch');
binaryPoints=strcmp(mode,'binary_points') || binaryRematch;
if nargin<2
    if finalPoint || binaryRematch,inductances_mH=15;else,inductances_mH=1000*cfg0.researchInductances;end
end
validateattributes(inductances_mH,{'numeric'},{'real','finite','vector','nonempty'});
inductances_mH=unique(inductances_mH(:)','stable');
[valid,indices]=ismember(inductances_mH,1000*cfg0.researchInductances);
assert(all(valid),'PAM3Full:Inductance','Use 10 mH, 15 mH, or both.');
if finalPoint || binaryRematch
    assert(isequal(inductances_mH,15),'PAM3Full:FinalPoint','This mode uses only 15 mH.');
end
VALIDATE_PAM3_LOGGING();VALIDATE_RESEARCH_STAGE3();
if ~finalPoint && ~binaryPoints,VALIDATE_PAM3_FULL();end
assert(exist('load_system','file')~=0 || exist('load_system','builtin')~=0, ...
    'PAM3Full:Simulink','MATLAB, Simulink and Specialized Power Systems are required.');
load_system('powerlib');
stamp=datestr(now,'yyyymmdd_HHMMSS_FFF');
folderName='research_stage4_results';
if finalPoint,folderName='final_dpc_results';end
if binaryPoints,folderName='binary_dpc_results';end
if binaryRematch,folderName='binary_dpc_rematch_results';end
folder=fullfile(root,folderName,['run_' stamp]);
assert(~isfolder(folder),'PAM3Full:Output','Output folder already exists.');
mkdir(folder);save(fullfile(folder,'stage4_config.mat'),'cfg0','cases','variants','mode','inductances_mH');
metrics=table();pairs=table();summary=table();mRows={};pRows={};
seedCounts=arrayfun(@(s)numel(s.Seeds),cases);
expectedCases=numel(indices)*sum(seedCounts);
if binaryPoints
    expectedCases=sum(seedCounts(ismember(cfg0.binaryCaseInductances_mH,inductances_mH)));
end
status=struct('StudyComplete',false,'CompletedCases',0,'ExpectedCases',expectedCases, ...
    'CompletedPairs',0,'ExpectedPairs',expectedCases*(2*numel(variants)-1), ...
    'ExpectedSimulations',expectedCases*(1+numel(variants)), ...
    'InputVerifiedPairs',0,'SwitchingComparablePairs',0, ...
    'VerifiedAndComparablePairs',0,'PlotErrors',0,'LastError','');
if binaryPoints
    status=rmfield(status,'ExpectedSimulations');
    status.MinimumSimulations=2*expectedCases;
    status.MaximumSimulations=(1+cfg0.binaryMaxBandTrials)*expectedCases;
    status.CompletedSimulations=0;
end
write_status(folder,status);
try
    for index=indices
        for j=1:numel(cases)
            if binaryPoints && round(1000*cfg0.researchInductances(index))~=cfg0.binaryCaseInductances_mH(j),continue;end
            s=cases(j);
            for seed=s.Seeds
                cfg=cfg0;cfg.modelL=cfg0.researchInductances(index);
                cfg.sourcePhaseScale=[s.PhaseA_RMS_V/cfg.e 1 1];
                isStep=s.Qafter_var~=0;
                if isStep
                    cfg.referenceMode='stepQ';cfg.Qafter=s.Qafter_var;
                    cfg.window=cfg.stepAnalysisWindow;
                end
                tag=sprintf('%02dmH_%s_seed%d',round(1000*cfg.modelL),s.Name,seed);
                caseFolder=fullfile(folder,tag);mkdir(caseFolder);
                fprintf('\nStage 4: %s / %s\n',tag,char(mode));
                r=cell(1,1+numel(variants));m=r;
                order=1:numel(r);
                if binaryPoints,order=[2 1];end
                for k=order
                    c=cfg;c.baselineBandScale=1;
                    if k==1
                        method='baseline';c.role='matched_baseline';
                        c.baselineBandScale=cfg0.frozenBaselineBands(index);
                        c.fullFeatures.adaptiveBand=false;c.fullFeatures.confidenceGate=false;
                        c.fullFeatures.persistence=false;
                    else
                        method=variants(k-1).Method;c.role=variants(k-1).Name;
                        c.fullFeatures=variants(k-1).Features;
                    end
                    c.modelPrefix=sprintf('DPC4_%s_c%02d_v%d_',stamp,status.CompletedCases+1,k);
                    c.outputFolder=fullfile(caseFolder,c.role);
                    if binaryPoints && k==1
                        c.role='binary_baseline';
                        [r{k},m{k},attempts]=binary_match(c,s,seed,r{2},m{2});
                        status.CompletedSimulations=status.CompletedSimulations+attempts+1;
                    else
                        r{k}=PAM3_STUDY_CASE(method,s.NoiseStd,seed,c);
                        m{k}=attach_observations(r{k},c,s);
                        close_system(r{k}.model,0);
                    end
                end
                if binaryRematch
                    m{2}.BinaryBandScaleP=NaN;
                    m{2}.BinaryBandScaleQ=NaN;
                end
                mRows(end+1:end+numel(m),1)=m(:); %#ok<AGROW>
                for candidate=2:numel(r)
                    references=1;
                    if candidate>2,references=[1 2];end
                    for reference=references
                        identicalNoise=same_noise(r{reference}.raw,r{candidate}.raw);
                        p=PAM3_STAGE3_COMPARE(m{reference},m{candidate},cfg,identicalNoise);
                        p.ReferenceRole=m{reference}.Role;p.CandidateRole=m{candidate}.Role;
                        p.AdaptiveBand=m{candidate}.AdaptiveBand;
                        p.ConfidenceGate=m{candidate}.ConfidenceGate;
                        p.Persistence=m{candidate}.Persistence;
                        if binaryRematch
                            p.BinaryBandScaleP=m{reference}.BinaryBandScaleP;
                            p.BinaryBandScaleQ=m{reference}.BinaryBandScaleQ;
                        end
                        pRows{end+1,1}=p; %#ok<AGROW>
                        if ~p.InputsVerified
                            warning('PAM3Full:Inputs','Input check failed for %s / %s.',tag,char(p.CandidateRole));
                        end
                    end
                end
                metrics=struct2table(vertcat(mRows{:}));pairs=struct2table(vertcat(pRows{:}));
                summary=struct2table(summarize(vertcat(pRows{:})));
                writetable(metrics,fullfile(folder,'stage4_metrics.csv'));
                writetable(pairs,fullfile(folder,'stage4_pairs.csv'));
                writetable(summary,fullfile(folder,'stage4_summary.csv'));
                status.CompletedCases=status.CompletedCases+1;status.CompletedPairs=height(pairs);
                status.InputVerifiedPairs=sum(pairs.InputsVerified);
                status.SwitchingComparablePairs=sum(pairs.SwitchingComparable);
                status.VerifiedAndComparablePairs=sum(pairs.InputsVerified & pairs.SwitchingComparable);
                write_status(folder,status);
                if finalPoint || binaryPoints,continue;end % No full-feature plots in the final pair.
                try
                    fullFolder=fullfile(caseFolder,'full');
                    PAM3_PLOT_FULL_FEATURES(r{end},cfg,fullFolder);
                    if isStep,PAM3_STAGE3_PLOT_STEP({r{1},r{end}},cfg,fullFolder);end
                catch plotProblem
                    status.PlotErrors=status.PlotErrors+1;write_status(folder,status);
                    write_text(fullfile(caseFolder,'plot_error.txt'),getReport(plotProblem));
                    warning('PAM3Full:Plot','Metrics saved; plot export failed for %s.',tag);
                end
            end
        end
    end
catch problem
    status.LastError=problem.message;write_status(folder,status);rethrow(problem);
end
status.StudyComplete=status.CompletedCases==status.ExpectedCases && status.CompletedPairs==status.ExpectedPairs;
if finalPoint
    status.FinalPoint=final_point_verdict(pairs);
    disp(pairs(:,{'Seed','THD_Change_pct','P_Ripple_Change_pct','Q_Ripple_Change_pct', ...
        'MaxSwitchingMismatch_pct','InputsVerified','SwitchingComparable','WindowScreenBothOK'}));
    fprintf('Final point verdict: %s\n',status.FinalPoint.Outcome);
end
write_status(folder,status);
fprintf('\nStage 4 complete: %d cases, %d comparisons.\n%s\n',status.CompletedCases,status.CompletedPairs,folder);
end

function [run,metrics,attempts]=binary_match(cfg,s,seed,target,targetMetrics)
% Bounded, per-pair matching based solely on switching mismatch.
% Save every attempt; do not select a band by THD or ripple.
scales=[1 .5 2 .25 4];
directions=zeros(0,2);fine=zeros(0,2);
if cfg.binaryRefineBands
    % Start inside the large gap in the old grid. Include the previous best
    % for this seed as a fallback, then vary the two widths independently.
    previous=1;if seed==3579,previous=.5;end
    scales=[.75 .625 .875 .6875 .8125 .5625 .9375 previous];
    directions=[1.25 .8;.8 1.25;1.25 1;.8 1;1 1.25;1 .8];
    fine=[1.1 1;1/1.1 1;1 1.1;1 1/1.1];
end
nCommon=numel(scales);nCoarse=size(directions,1);nFine=size(fine,1);
assert(nCommon+nCoarse+nFine<=cfg.binaryMaxBandTrials);
best=Inf;bestScales=[NaN NaN];rows=cell(0,1);tried=zeros(0,2);
mkdir(cfg.outputFolder);
for i=1:nCommon+nCoarse+nFine
    if i<=nCommon
        bands=[scales(i) scales(i)];
    else
        if ~isfinite(best),break;end
        if i==nCommon+1 || i==nCommon+nCoarse+1,center=bestScales;end
        if i<=nCommon+nCoarse
            bands=center.*directions(i-nCommon,:);
        else
            bands=center.*fine(i-nCommon-nCoarse,:);
        end
        bands=min(4,max(.25,bands));
    end
    if any(all(abs(tried-bands)<1e-10,2)),continue;end
    tried(end+1,:)=bands; %#ok<AGROW>
    c=cfg;c.baselineBandScale=bands(1);
    if cfg.binaryRefineBands,c.binaryBandScales=bands;end
    c.modelPrefix=[cfg.modelPrefix sprintf('b%d_',i)];
    if cfg.binaryRefineBands
        c.outputFolder=fullfile(cfg.outputFolder,sprintf('b%02d',i));
    else
        c.outputFolder=fullfile(cfg.outputFolder,sprintf('band_%g',scales(i)));
    end
    a=PAM3_STUDY_CASE('binary',s.NoiseStd,seed,c);
    close_system(a.model,0);
    m=attach_observations(a,c,s);
    if cfg.binaryRefineBands
        logged=[m.P_EnterMinPu m.P_EnterMaxPu m.Q_EnterMinPu m.Q_EnterMaxPu];
        expected=.01*bands([1 1 2 2]);
        assert(all(abs(logged-expected)<1e-12),'PAM3Binary:BandNotApplied', ...
            'Logged binary thresholds do not match the requested P/Q bands.');
        m.BinaryBandScaleP=bands(1);m.BinaryBandScaleQ=bands(2);
        if bands(1)~=bands(2),m.BaselineBandScale=NaN;end
    end
    p=PAM3_STAGE3_COMPARE(m,targetMetrics,c,same_noise(a.raw,target.raw));
    if cfg.binaryRefineBands
        p.BinaryBandScaleP=bands(1);p.BinaryBandScaleQ=bands(2);
    end
    rows{end+1,1}=p; %#ok<AGROW>
    writetable(struct2table(vertcat(rows{:})),fullfile(cfg.outputFolder,'band_attempts.csv'));
    score=p.MaxSwitchingMismatch_pct;
    if cfg.binaryRefineBands
        fprintf('Binary bands P=%.5g, Q=%.5g; max switching mismatch %.2f%%.\n',bands(1),bands(2),score);
    end
    if ~p.InputsVerified || ~p.WindowScreenBothOK || ~isfinite(score),continue;end
    if score<best
        run=a;metrics=m;best=score;bestScales=bands;
    end
    if p.SwitchingComparable,break;end
end
attempts=numel(rows);
assert(isfinite(best),'PAM3Binary:NoValidReference','No valid binary reference; see band_attempts.csv.');
if best>100*cfg.switchingToleranceFraction
    warning('PAM3Binary:Unmatched','Best binary switching mismatch %.2f%% exceeds tolerance.',best);
end
end

function v=final_point_verdict(pairs)
% Report all runs and keep excluded pairs out of the confirmatory averages.
eligible=pairs.InputsVerified & pairs.SwitchingComparable & pairs.WindowScreenBothOK;
metrics={'THD_Change_pct','P_Ripple_Change_pct','Q_Ripple_Change_pct', ...
    'P_Tracking_Change_pct','Q_Tracking_Change_pct'};
eligible=eligible & all(isfinite(pairs{:,metrics}),2);
v.EligiblePairs=sum(eligible);v.TotalPairs=height(pairs);
v.EligibleSeeds=pairs.Seed(eligible)';
v.ExcludedSeeds=pairs.Seed(~eligible)';
v.QRippleImprovedPairs=sum(eligible & pairs.Q_Ripple_Change_pct<0);
for k=1:numel(metrics)
    v.(['Mean_' metrics{k}])=mean(pairs.(metrics{k})(eligible));
end
if v.EligiblePairs<v.TotalPairs
    v.Outcome='INCONCLUSIVE_SWITCHING_OR_VALIDATION';
elseif v.QRippleImprovedPairs==v.TotalPairs && ...
        v.Mean_THD_Change_pct<=0 && v.Mean_P_Ripple_Change_pct<=0
    v.Outcome='CONFIRMED_Q_RIPPLE_WITHOUT_MEAN_THD_OR_P_RIPPLE_PENALTY';
else
    v.Outcome='TRADEOFF_OR_IMPROVEMENT_NOT_CONFIRMED';
end
end

function m=attach_observations(run,cfg,spec)
m=run.metrics;
stats=PAM3_FULL_FEATURE_STATS(run.raw,cfg);
keys=fieldnames(stats);
for j=1:numel(keys),m.(keys{j})=stats.(keys{j});end
f=cfg.fullFeatures;
m.AdaptiveBand=logical(f.adaptiveBand);m.ConfidenceGate=logical(f.confidenceGate);
m.Persistence=logical(f.persistence);
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
    'WindowStart_s','WindowEnd_s','BaselineBandScale','ReferenceRole','CandidateRole', ...
    'AdaptiveBand','ConfidenceGate','Persistence'};
for k=1:numel(p)
    same=([p.L_mH]==p(k).L_mH) & ([p.Case]==p(k).Case) & ...
        ([p.ReferenceRole]==p(k).ReferenceRole) & ([p.CandidateRole]==p(k).CandidateRole);
    if find(same,1)~=k,continue;end
    g=p(same);a=struct();
    for j=1:numel(fixed),a.(fixed{j})=p(k).(fixed{j});end
    if numel(unique([g.BaselineBandScale]))>1,a.BaselineBandScale=NaN;end
    for name={'BinaryBandScaleP','BinaryBandScaleQ'}
        if isfield(g,name{1})
            values=unique([g.(name{1})]);
            a.(name{1})=NaN;
            if isscalar(values),a.(name{1})=values;end
        end
    end
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
write_text(fullfile(folder,'stage4_status.json'),jsonencode(status,'PrettyPrint',true));
end

function write_text(path,content)
fid=fopen(path,'w');
assert(fid>=0,'PAM3Stage3:File','Cannot write %s.',path);
fwrite(fid,content,'char');fclose(fid);
end
