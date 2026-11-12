function [T,results,verdict]=RUN_PAM3_STUDY(cfg)
% 13 runs per fs/L pair: 4 clean + 3 methods x 3 matched sensor-noise seeds.
root=fileparts(mfilename('fullpath'));
if nargin<1,cfg=pam3_study_config();end
validateattributes(cfg.noiseStd,{'numeric'},{'vector','numel',2,'real','finite','nonnegative'});
assert(any(cfg.noiseStd>0),'PAM3Study:NoiseLevel','Specify nonzero sensor noise for noisy tests.');
folder=fullfile(root,'results');
if isfield(cfg,'outputFolder'),folder=cfg.outputFolder;end
cfg.outputFolder=folder;
if ~isfolder(folder),mkdir(folder);end
DIAGNOSE_OLD_MAPPING();
VALIDATE_PAM3_IMPROVED();
VALIDATE_STUDY_CONNECTIONS();
VALIDATE_SENSOR_NOISE();
results=cell(4+3*numel(cfg.seeds),1);j=0;
for method={'baseline','compatible','adaptive','predictive'}
 j=j+1;results{j}=PAM3_STUDY_CASE(method{1},[0 0],cfg.cleanSeed,cfg);
end
for seed=cfg.seeds
 for method={'baseline','adaptive','predictive'}
  j=j+1;results{j}=PAM3_STUDY_CASE(method{1},cfg.noiseStd,seed,cfg);
 end
end
results=results(1:j);
rows=cellfun(@(x)x.metrics,results,'UniformOutput',false);T=struct2table(vertcat(rows{:}));
[verdict,pairs]=assess(results,cfg);
writetable(T,fullfile(folder,'comparison_metrics.csv'));
writetable(pairs,fullfile(folder,'paired_comparison.csv'));
save(fullfile(folder,'comparison_results.mat'),'results','T','cfg','verdict','pairs');
fid=fopen(fullfile(folder,'verdict.json'),'w');assert(fid>=0);
fwrite(fid,jsonencode(verdict,PrettyPrint=true),'char');fclose(fid);
disp(T(:,{'Method','NoiseVoltageStd_V','NoiseCurrentStd_A','Seed', ...
 'P_ripple_RMS_W','Q_ripple_RMS_var','I_THD_mean_pct','SwitchCyclesPerLeg_Hz'}));
disp(verdict);
plotpair(results{1},results{4},'Clean sensor measurements',fullfile(folder,'clean_comparison.png'));
plotpair(results{5},results{7},'Voltage/current sensor noise, first seed',fullfile(folder,'noisy_comparison.png'));
fprintf('Saved results in: %s\n',folder);
end
function [v,pairs]=assess(r,cfg)
% Physical signal equality is checked only for baseline vs compatible CLEAN.
keys={'P','Q','I','Vdc','sp','sq','S1','S2','S3'};
v.CompatibilityMaxDifference=0;
for k=1:numel(keys)
 a=r{1}.raw.(keys{k});b=r{2}.raw.(keys{k});
 if ~isequal(a.time,b.time) || ~isequal(a.signals.values,b.signals.values)
  v.CompatibilityMaxDifference=inf;
 end
end
v.CompatibilityExact=isfinite(v.CompatibilityMaxDifference);
% Compare INJECTED noise, not measured voltage/current (plants differ).
v.MatchedSensorNoiseExact=true;
for k=1:numel(cfg.seeds)
 idx=5+(k-1)*3;
 for j=idx+1:idx+2
  for key={'NoiseV','NoiseI'}
   a=r{idx}.raw.(key{1});b=r{j}.raw.(key{1});
   v.MatchedSensorNoiseExact=v.MatchedSensorNoiseExact && ...
    isequal(a.time,b.time) && isequal(a.signals.values,b.signals.values);
  end
 end
end
[v.BandOnlyCandidate,p1]=evaluate(r,'adaptive',cfg);
[v.ModelAssistedCandidate,p2]=evaluate(r,'predictive',cfg);
pairs=struct2table([p1;p2]);
v.QualityCandidateAccepted=v.CompatibilityExact && v.MatchedSensorNoiseExact && ...
 v.ModelAssistedCandidate.QualityAccepted;
v.CandidateAccepted=v.CompatibilityExact && v.MatchedSensorNoiseExact && ...
 v.ModelAssistedCandidate.AcceptedAtComparableSwitching;
v.SwitchingToleranceFraction=cfg.switchingToleranceFraction;
v.NoiseLocation='vabc/iabc measurement inputs before power calculation, sector choice and observer';
if v.CandidateAccepted
 v.Message='Quality improvement passed in THESE cases with switching mismatch within tolerance on each leg and the mean.';
elseif v.QualityCandidateAccepted
 v.Message='Quality improved, but comparable-switching requirement FAILED; do not claim improvement at equal switching frequency.';
else
 v.Message='Improvement NOT established under the configured gates; inspect all rows.';
end
v.Limitations=['Finite cases; engineering tolerances; THD harmonics 2..40. ' ...
 'No automatic switching-rate tuning. No physical grid distortion or switching-loss simulation. ' ...
 'Sensor noise std per sample is fixed across sampling rates; sampled noise bandwidth changes. ' ...
 'Existing adaptation counters remain sample-based, so their time scales change with fs.'];
end
function [v,p]=evaluate(r,method,cfg)
b=select(r,'baseline',[0 0],cfg.cleanSeed);a=select(r,method,[0 0],cfg.cleanSeed);
p=PAM3_COMPARE_CASES(b,a,cfg);
v.CleanAcceptable=p.QualityAcceptable;
v.CleanSwitchingComparable=p.SwitchingComparable;
for k=1:numel(cfg.seeds)
 b=select(r,'baseline',cfg.noiseStd,cfg.seeds(k));
 a=select(r,method,cfg.noiseStd,cfg.seeds(k));
 p(k+1,1)=PAM3_COMPARE_CASES(b,a,cfg); %#ok<AGROW>
end
v.NoisyAcceptableBySeed=[p(2:end).QualityAcceptable];
v.NoisyUsefulBySeed=[p(2:end).QualityUseful];
v.NoisySwitchingComparableBySeed=[p(2:end).SwitchingComparable];
v.QualityAccepted=v.CleanAcceptable && all(v.NoisyUsefulBySeed);
v.AcceptedAtComparableSwitching=v.QualityAccepted && v.CleanSwitchingComparable && ...
 all(v.NoisySwitchingComparableBySeed);
v.Accepted=v.AcceptedAtComparableSwitching;
end
function m=select(r,method,noise,seed)
for k=1:numel(r)
 m=r{k}.metrics;
 if m.Method==string(method) && m.NoiseVoltageStd_V==noise(1) && ...
   m.NoiseCurrentStd_A==noise(2) && m.Seed==seed,return;end
end
error('PAM3Study:MissingCase','Missing comparison case.');
end
function plotpair(b,a,titleText,path)
f=figure('Name',titleText,'Color','w');tiledlayout(3,1);
nexttile;plot(b.raw.P.time,b.raw.P.signals.values,a.raw.P.time,a.raw.P.signals.values);
ylabel('Physical P (W)');title(titleText);legend('Professor','Causal model-assisted adaptation');grid on;
nexttile;plot(b.raw.Q.time,b.raw.Q.signals.values,a.raw.Q.time,a.raw.Q.signals.values);
ylabel('Physical Q (var)');grid on;
nexttile;i=b.raw.I.signals.values;ii=a.raw.I.signals.values;
plot(b.raw.I.time,i(:,1),a.raw.I.time,ii(:,1));xlim([.30 .36]);
ylabel('Phase A current (A)');xlabel('Time (s)');grid on;saveas(f,path);
end
