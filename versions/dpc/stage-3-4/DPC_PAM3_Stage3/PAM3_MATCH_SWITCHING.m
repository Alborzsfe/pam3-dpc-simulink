function calibration=PAM3_MATCH_SWITCHING(cfg,folder)
% Tune ONLY professor-band multiplier, using clean + independent noisy runs.
% Freeze the result across all subsequent test seeds/distortion/step cases.
noise={[0 0],cfg.noiseStd};targets=cell(1,2);records={};
for j=1:2
    c=cfg;c.role='calibration_proposed';
    c.outputFolder=fullfile(folder,['target_' num2str(j)]);
    r=PAM3_STUDY_CASE('predictive',noise{j},cfg.calibrationSeed,c);
    targets{j}=r.metrics;
end
scales=[];scores=[];
for scale=cfg.bandGrid,evaluate(scale);end
[~,best]=min(scores);sorted=sort(scales);index=find(sorted==scales(best),1);
lo=sorted(max(1,index-1));hi=sorted(min(numel(sorted),index+1));
% Refine without assuming monotonic switching frequency vs hysteresis band.
for scale=linspace(lo,hi,7)
    if all(abs(scales-scale)>1e-10),evaluate(scale);end
end
bestScore=min(scores);ties=find(abs(scores-bestScore)<1e-12);
[~,closest]=min(abs(log(scales(ties))));best=ties(closest);
calibration.BandScale=scales(best);
calibration.MaxRelativeSwitchMismatch=scores(best);
calibration.CalibrationMatched=scores(best)<=cfg.switchingToleranceFraction;
calibration.CalibrationSeed=cfg.calibrationSeed;
calibration.Criteria='Minimize worst relative switching mismatch across each leg/mean in clean and independent-noise calibration; no quality-based selection.';
calibration.NoisyEvaluationSeeds=cfg.seeds;
calibration.Scales=scales;calibration.Scores=scores;
save(fullfile(folder,'calibration.mat'),'calibration','targets','cfg');
fid=fopen(fullfile(folder,'calibration.json'),'w');assert(fid>=0);
fwrite(fid,jsonencode(calibration,PrettyPrint=true),'char');fclose(fid);
fprintf('Frozen baseline band scale %.6g; calibration mismatch %.2f%% (matched=%d).\n', ...
    calibration.BandScale,100*calibration.MaxRelativeSwitchMismatch,calibration.CalibrationMatched);
    function evaluate(scale)
        b=cell(1,2);
        for jj=1:2
            c=cfg;c.baselineBandScale=scale;c.role='calibration_baseline';
            c.outputFolder=fullfile(folder,sprintf('band_%0.9g_case%d',scale,jj));
            r=PAM3_STUDY_CASE('baseline',noise{jj},cfg.calibrationSeed,c);
            b{jj}=r.metrics;records{end+1,1}=r.metrics; %#ok<AGROW>
        end
        scales(end+1)=scale;scores(end+1)=PAM3_SWITCH_SCORE(b,targets); %#ok<AGROW>
        rows=vertcat(records{:});
        writetable(struct2table(rows),fullfile(folder,'calibration_all_metrics.csv'));
        scoreTable=table(scales(:),scores(:),'VariableNames',{'BandScale','MaxRelativeSwitchMismatch'});
        writetable(scoreTable,fullfile(folder,'calibration_switching_scores.csv'));
    end
end
