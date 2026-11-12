function model = BUILD_PAM3_STUDY_MODEL(method, noiseStd, seed, cfg)
% Build with native MATLAB/Simulink APIs; no forced closing of open models.
if nargin<4,cfg=pam3_study_config();end
root=fileparts(mfilename('fullpath'));
validateattributes(noiseStd,{'numeric'},{'vector','numel',2,'real','finite','nonnegative'});
validateattributes(cfg.Ts,{'numeric'},{'scalar','real','finite','positive'});
assignin('base','Ts_DPC',cfg.Ts); assignin('base','e',cfg.e);
folder=fullfile(root,'generated_models'); if ~isfolder(folder),mkdir(folder);end
switch method
    case 'baseline', template='baseline'; gain=0;
    case 'binary', template='binary'; gain=0;
    case 'compatible', template='fast'; gain=0;
    case 'adaptive', template='fast'; gain=cfg.adaptiveGain;
    case 'predictive', template='predictive'; gain=0;
    case 'predictive_full', template='predictive_full'; gain=0;
    case 'legacy', template='legacy'; gain=0;
    case 'raw', template='raw'; gain=0;
    case 'adc', template='adc'; gain=0;
    case 'delay', template='delay'; gain=0;
    otherwise,error('PAM3Study:Method','Unknown method: %s',method);
end
model=['DPC2_' method];
if isfield(cfg,'modelPrefix'),model=[cfg.modelPrefix method];end
if isfield(cfg,'shortBuildPaths') && cfg.shortBuildPaths
    model=PAM3_SHORT_MODEL_NAME(model);
end
destination=fullfile(folder,[model '.slx']);
if bdIsLoaded(model)
    loaded=get_param(model,'FileName');
    if ispc,same=strcmpi(loaded,destination);else,same=strcmp(loaded,destination);end
    assert(same,'PAM3Study:NameCollision', ...
        'A comparison model %s is open from another folder. Save and close that copy first.',model);
else
    if ~isfile(destination)
        [ok,msg]=copyfile(fullfile(root,'DPC_Three_Level.slx'),destination);
        assert(ok,'PAM3Study:Copy','Cannot create copy: %s',msg);
    end
    load_system(destination);
end
% Apply on EVERY build, including already-loaded/generated copies. The plant
% and predictor must use the same inductance for these matched-model studies.
validateattributes(cfg.modelL,{'numeric'},{'scalar','real','finite','positive'});
set_param([model '/L Filter'],'Inductance',num2str(cfg.modelL,17));
code=fileread(fullfile(root,'controllers',[template '_template.m']));
keys={'__SEED__','__NOISE_P__','__NOISE_Q__','__GAIN__','__NOISE_FLOOR__','__TS__','__R__','__L__','__BLEND__'};
% Controller templates receive ZERO additional P/Q noise. All methods see
% the same six noisy sensor channels, installed below, including sector logic.
values=[seed,0,0,gain,cfg.noiseFloorPu,cfg.Ts,cfg.modelR,cfg.modelL,cfg.maxObserverBlend];
for j=1:numel(keys),code=strrep(code,keys{j},sprintf('%.17g',values(j)));end
if strcmp(method,'predictive_full'),code=PAM3_RENDER_FULL_FEATURES(code,cfg);end
code=PAM3_RENDER_DIAGNOSTICS(code,template,method,cfg);
chart=find(sfroot,'-isa','Stateflow.EMChart','Path',[model '/MATLAB Function3']);
assert(numel(chart)==1,'PAM3Study:Chart','Expected one controller chart.');
chart.Script=code;
chart.ChartUpdate='DISCRETE';chart.SampleTime=num2str(cfg.Ts,17);
if strcmp(method,'predictive') || strcmp(method,'predictive_full')
    % Stateflow's Script setter parses the fifth input; ensure its data exists.
    data=find(chart,'-isa','Stateflow.Data','Name','Vdc');
    if isempty(data)
        data=Stateflow.Data(chart);data.Name='Vdc';data.Scope='Input';data.Port=5;
    end
    ph=get_param([model '/MATLAB Function3'],'PortHandles');
    assert(numel(ph.Inport)==5,'PAM3Study:Ports','Expected DC measurement input 5.');
    vph=get_param([model '/Scope1'],'PortHandles');
    vline=get_param(vph.Inport(1),'Line');
    source=get_param(vline,'SrcPortHandle');
    while source==-1
        vline=get_param(vline,'LineParent');
        assert(vline~=-1 && vline~=0,'PAM3Study:VdcSource','DC source is disconnected.');
        source=get_param(vline,'SrcPortHandle');
    end
    PAM3_STUDY_CONNECT(get_param(source,'Parent'),get_param(source,'PortNumber'), ...
        [model '/MATLAB Function3'],5);
end
PAM3_INSTALL_SENSOR_NOISE(model,noiseStd,seed,cfg);
if isfield(cfg,'researchMode') && cfg.researchMode
    PAM3_INSTALL_RESEARCH_INPUTS(model,cfg);
end
set_param(model,'FastRestart','off');
set_param(model,'StopTime',num2str(cfg.stopTime,17),'SimulationMode','normal');
% Study data comes only from the named periodic To Workspace sinks. Avoid
% duplicate Dataset logging in generated copies; retain SDI's disk safeguards.
set_param(model,'StartTime','0','LoggingIntervals','[-inf, inf]', ...
    'SignalLogging','off','DSMLogging','off','SaveOutput','off', ...
    'SaveState','off','SaveTime','off','InspectSignalLogs','off');
set_param(model,'SimulationCommand','update');
save_system(model);
end
