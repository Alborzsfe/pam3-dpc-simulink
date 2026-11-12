function PAM3_INSTALL_RESEARCH_INPUTS(model,cfg)
% Research copies only. Drive PHYSICAL sources, never just measured voltage.
root=fileparts(mfilename('fullpath'));clock=[model '/Research_Clock'];
if getSimulinkBlockHandle(clock)==-1
    add_block('simulink/Sources/Clock',clock,'Position',[40 820 70 840]);
end
generator=[model '/Research_Grid_5th_7th'];
code=sprintf(['function [va,vb,vc]=fcn(t)\n' ...
 'v=pam3_grid_wave(t,%.17g,%.17g,%.17g);va=v(1);vb=v(2);vc=v(3);\nend\n'], ...
 cfg.e,cfg.fundamentalHz,cfg.sourceTHD);
code=[code fileread(fullfile(root,'pam3_grid_wave.m'))];
install_chart(generator,code,[160 800 355 870]);
PAM3_STUDY_CONNECT(clock,1,generator,1);
% Copy the exact library path used by the original controlled C source.
csource=[model '/Controlled Voltage Source'];
lib=get_param(csource,'ReferenceBlock');
if isempty(lib),lib=get_param(csource,'SourceBlock');end
load_system(strtok(lib,'/'));
names={['A' newline newline],'B','Controlled Voltage Source'};
for k=1:3
    source=[model '/' names{k}];
    ports=get_param(source,'PortHandles');
    if isempty(ports.Inport)
        replacement=replace_block(model,'SearchDepth',1,'Name',names{k},lib,'noprompt');
        assert(~isempty(replacement),'PAM3Study:GridSource','Source replacement failed.');
    end
    phase=[0 -120 120];
    set_param(source,'Initialize','off','Frequency',num2str(cfg.fundamentalHz,17), ...
        'Amplitude',num2str(cfg.e*sqrt(2),17),'Phase',num2str(phase(k)));
    ports=get_param(source,'PortHandles');
    assert(numel(ports.Inport)==1 && numel(ports.LConn)==1 && numel(ports.RConn)==1, ...
        'PAM3Study:GridSourcePorts','Unexpected physical source interface.');
    % Source replacement must preserve the original electrical connections.
    assert(get_param(ports.LConn(1),'Line')~=-1 && get_param(ports.RConn(1),'Line')~=-1, ...
        'PAM3Study:GridWiring','A physical source terminal was disconnected during replacement.');
    PAM3_STUDY_CONNECT(generator,k,source,1);
end
if ~strcmp(cfg.referenceMode,'outer_voltage')
    reference=[model '/Research_PQ_Reference'];
    p0=cfg.Pbefore;p1=cfg.Pafter;q0=cfg.Qbefore;q1=cfg.Qafter;
    if strcmp(cfg.referenceMode,'fixed_power'),p0=cfg.Pnom;p1=cfg.Pnom;q0=0;q1=0;end
    code=sprintf(['function [p,q]=fcn(t)\n' ...
      '[p,q]=pam3_reference_profile(t,%.17g,%.17g,%.17g,%.17g,%.17g);\nend\n'], ...
      cfg.stepTime,p0,p1,q0,q1);
    code=[code fileread(fullfile(root,'pam3_reference_profile.m'))];
    install_chart(reference,code,[160 925 355 980]);
    PAM3_STUDY_CONNECT(clock,1,reference,1);
    PAM3_STUDY_CONNECT(reference,1,[model '/MATLAB Function3'],3);
    PAM3_STUDY_CONNECT(reference,2,[model '/MATLAB Function3'],4);
end
end
function install_chart(path,code,position)
if getSimulinkBlockHandle(path)==-1
    add_block('simulink/User-Defined Functions/MATLAB Function',path,'Position',position);
end
chart=find(sfroot,'-isa','Stateflow.EMChart','Path',path);
assert(numel(chart)==1,'PAM3Study:Chart','Cannot find research input chart.');
chart.Script=code;chart.ChartUpdate='INHERITED';
end
