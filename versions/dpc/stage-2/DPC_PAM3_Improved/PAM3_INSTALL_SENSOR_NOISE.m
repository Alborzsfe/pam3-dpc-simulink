function PAM3_INSTALL_SENSOR_NOISE(model,noiseStd,seed,cfg)
% Insert at the controller voltage/current inputs; preserve physical scopes.
root=fileparts(mfilename('fullpath'));
path=[model '/Study_Sensor_Noise'];controller=[model '/MATLAB Function3'];
if getSimulinkBlockHandle(path)==-1
    [vblock,vport]=PAM3_INPUT_SOURCE(controller,1);
    [iblock,iport]=PAM3_INPUT_SOURCE(controller,2);
    add_block('simulink/User-Defined Functions/MATLAB Function',path, ...
        'Position',[90 640 290 770]);
else
    % Reuse clean upstream endpoints when rebuilding an existing model.
    [vblock,vport]=PAM3_INPUT_SOURCE(path,1);
    [iblock,iport]=PAM3_INPUT_SOURCE(path,2);
end
chart=find(sfroot,'-isa','Stateflow.EMChart','Path',path);
assert(numel(chart)==1,'PAM3Study:SensorChart','Missing measurement chart.');
code=fileread(fullfile(root,'controllers','sensor_template.m'));
keys={'__SEED__','__SIGMA_V__','__SIGMA_I__'};
values=[seed noiseStd(:)'];
for k=1:numel(keys),code=strrep(code,keys{k},sprintf('%.17g',values(k)));end
code=[code newline fileread(fullfile(root,'pam3_sensor_step.m'))];
chart.Script=code;chart.ChartUpdate='DISCRETE';chart.SampleTime=num2str(cfg.Ts,17);
PAM3_STUDY_CONNECT(vblock,vport,path,1);
PAM3_STUDY_CONNECT(iblock,iport,path,2);
PAM3_STUDY_CONNECT(path,1,controller,1);
PAM3_STUDY_CONNECT(path,2,controller,2);
% The professor's P/Q scope must display true plant power, not sensor error.
PAM3_STUDY_CONNECT(path,3,[model '/Scope'],1);
PAM3_STUDY_CONNECT(path,4,[model '/Scope'],2);
% Sanity checks catch duplicate/wrong branch wiring before any simulation.
for k=1:2
    [b,p]=PAM3_INPUT_SOURCE(controller,k);
    assert(strcmp(b,path) && p==k,'PAM3Study:SensorWiring','Sensor path bypassed.');
end
end
