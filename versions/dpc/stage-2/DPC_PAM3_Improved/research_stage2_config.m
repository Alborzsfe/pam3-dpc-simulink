function cfg=research_stage2_config()
cfg=pam3_study_config();
cfg.researchMode=true;cfg.baselineBandScale=1;cfg.sourceTHD=0;
cfg.referenceMode='fixed_power';cfg.Pnom=400;cfg.Pbefore=240;cfg.Pafter=400;
cfg.Qbefore=0;cfg.Qafter=80;cfg.stepTime=.10;
cfg.researchFrequencies=40000;cfg.researchInductances=[15e-3 10e-3];
cfg.calibrationSeed=7777;
cfg.bandGrid=[.10 .20 .35 .50 .65 .80 1 1.20 1.50];
cfg.noiseLevels=[.25 .025;.50 .050;1.0 .100];
cfg.sourceTHDLevels=[.03 .05];
cfg.dynamicStopTime=.25;cfg.dynamicWindow=[.20 .24];
cfg.dynamicPreWindow=[.06 .09];cfg.dynamicTailDuration=.02;
cfg.settlingBandFraction=.02;cfg.settlingDwell=.01;
cfg.modelPrefix='DPC3_steady_';
end
