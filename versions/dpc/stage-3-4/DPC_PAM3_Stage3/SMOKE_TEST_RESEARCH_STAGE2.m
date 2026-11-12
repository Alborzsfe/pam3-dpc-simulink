function report=SMOKE_TEST_RESEARCH_STAGE2()
% Six short NATIVE simulations before the longer suite. Wiring, not quality.
root=fileparts(mfilename('fullpath'));cfg=research_stage2_config();
VALIDATE_RESEARCH_STAGE2();
folder=fullfile(root,'research_smoke',['run_' datestr(now,'yyyymmdd_HHMMSS_FFF')]);mkdir(folder);
cfg.stopTime=.06;cfg.window=[.02 .06];cfg.stepTime=.03;
cfg.dynamicPreWindow=[.01 .02];cfg.dynamicTailDuration=.01;
names={'clean','harmonics3','harmonics5','stepP','stepQ','sensors'};
rows=cell(6,1);
for k=1:6
 c=cfg;c.modelPrefix=['DPC3_smoke_' names{k} '_'];
 c.outputFolder=fullfile(folder,names{k});noise=[0 0];method='baseline';
 if k==1,c.baselineBandScale=.8;end
 if k==2,c.sourceTHD=.03;end
 if k==3,c.sourceTHD=.05;end
 if k==4,c.referenceMode='stepP';c.Qafter=0;end
 if k==5,c.referenceMode='stepQ';c.Pbefore=400;method='predictive';end
 if k==6,noise=c.noiseStd;method='predictive';end
 r=PAM3_STUDY_CASE(method,noise,c.cleanSeed,c);m=r.metrics;
 assert(abs(m.V_THD_mean_pct-100*c.sourceTHD)<.25, ...
  'PAM3Study:PhysicalHarmonics','PCC voltage THD differs from physical source target.');
 if k==1
  d=PAM3_SAMPLE(r.raw.Diagnostics,.04);
  assert(max(abs(d(5:8)-[.008 .004 .008 .004]))<1e-12);
 end
 if k==4
  ref=PAM3_SAMPLE(r.raw.Pref,[.029;.031]);assert(isequal(ref,[240;400]));
 end
 if k==5
  ref=PAM3_SAMPLE(r.raw.Qref,[.029;.031]);assert(isequal(ref,[0;80]));
 end
 m.SmokeCase=string(names{k});rows{k}=m;
 writetable(struct2table(vertcat(rows{1:k})),fullfile(folder,'smoke_metrics.csv'));
end
report=struct2table(vertcat(rows{:}));
fprintf('PASS: SIX short native simulations: grid wiring, physical harmonics, P/Q references, diagnostics and sensor paths.\n');
fprintf('Saved smoke tests: %s\n',folder);
end
