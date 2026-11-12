function metrics=SMOKE_TEST_PAM3_FULL()
% Eight short native converter runs. Not the full performance experiment.
root=fileparts(mfilename('fullpath'));addpath(root);VALIDATE_PAM3_FULL();
[cfg,~,~]=research_stage4_config('full');
cfg.stopTime=.08;cfg.window=[.06 .08];cfg.modelL=.015;
cfg.sourcePhaseScale=[1 1 1];
stamp=datestr(now,'yyyymmdd_HHMMSS_FFF');
folder=fullfile(root,'research_stage4_smoke',['run_' stamp]);mkdir(folder);
rows={};
for noiseIndex=1:2
    noise=[0 0];if noiseIndex==2,noise=[.5 .05];end
    methods={'baseline','predictive','predictive_full','predictive_full'};
    roles={'reference','observer_only','all_features_disabled','full'};r=cell(1,4);
    for k=1:4
        c=cfg;c.role=roles{k};c.baselineBandScale=1;
        if k==1,c.baselineBandScale=.8;end
        if k<4
            c.fullFeatures.adaptiveBand=false;c.fullFeatures.confidenceGate=false;
            c.fullFeatures.persistence=false;
        end
        c.modelPrefix=sprintf('DPC4_smoke_%s_n%d_v%d_',stamp,noiseIndex,k);
        c.outputFolder=fullfile(folder,sprintf('noise%d_%s',noiseIndex,roles{k}));
        r{k}=PAM3_STUDY_CASE(methods{k},noise,cfg.cleanSeed,c);
        close_system(r{k}.model,0);
        s=PAM3_FULL_FEATURE_STATS(r{k}.raw,c);
        m=r{k}.metrics;keys=fieldnames(s);
        for j=1:numel(keys),m.(keys{j})=s.(keys{j});end
        rows{end+1,1}=m; %#ok<AGROW>
    end
    n=round(diff(cfg.window)/cfg.Ts);
    t=cfg.window(1)+((0:n-1)'+.5)*cfg.Ts;
    for key={'S1','S2','S3'}
        a=PAM3_SAMPLE(r{2}.raw.(key{1}),t);b=PAM3_SAMPLE(r{3}.raw.(key{1}),t);
        assert(isequal(a,b),'PAM3Full:NativeCompatibility','Disabled new path changed native gate commands.');
    end
    for key={'P','Q'}
        a=PAM3_SAMPLE(r{2}.raw.(key{1}),t);b=PAM3_SAMPLE(r{3}.raw.(key{1}),t);
        assert(max(abs(a-b))<1e-8,'PAM3Full:NativePower','Disabled new path changed native P/Q.');
    end
    d=PAM3_SAMPLE(r{4}.raw.Diagnostics,t);
    assert(size(d,2)==42 && all(isfinite(d(:))),'PAM3Full:Trace','Invalid full-feature trace.');
    assert(all(d(:,5)>=.01 & d(:,5)<=.015) && all(d(:,7)>=.01 & d(:,7)<=.015));
    assert(all(d(:,20)>=0 & d(:,20)<=3) && all(d(:,34)>=0 & d(:,34)<=3));
    c=cfg;c.fullFeatures=cfg.fullFeatures;
    PAM3_PLOT_FULL_FEATURES(r{4},c,fullfile(folder,sprintf('noise%d_full',noiseIndex)));
end
metrics=struct2table(vertcat(rows{:}));
writetable(metrics,fullfile(folder,'smoke_metrics.csv'));
fprintf('PASS: eight native converter smoke runs; disabled-path gate/PQ compatibility and full diagnostics.\n%s\n',folder);
end
