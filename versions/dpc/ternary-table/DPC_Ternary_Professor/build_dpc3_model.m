function [model,info] = build_dpc3_model(method,fs,cfg)
root = fileparts(mfilename('fullpath')); addpath(fullfile(root,'matlab'));
dpc3_validate_config(cfg);
assert(any(strcmp(method,{'conventional','binary_limit','proposed','bypass'})));
model = dpc3_copy_source(sprintf('DPC3_%s_%gk',method,fs/1000),root);
ws = get_param(model,'ModelWorkspace'); ts = 1/fs;
assignin(ws,'control_Ts',ts); assignin(ws,'plant_Ts',cfg.plant_step);
assignin(ws,'Ts',ts); assignin(ws,'e',cfg.phase_rms_voltage);
assignin(ws,'line_frequency',cfg.line_frequency);
set_param([model '/powergui'],'SampleTime','plant_Ts','frequency','line_frequency');
set_param(model,'SolverType','Fixed-step','Solver','ode3','FixedStep','plant_Ts', ...
    'StartTime','0','StopTime',sprintf('%.17g',cfg.stop_time),'SimulationMode','normal', ...
    'ReturnWorkspaceOutputs','on','SaveTime','off','SaveOutput','off','SignalLogging','off');
sines = find_system([model '/Subsystem2'],'SearchDepth',1,'BlockType','Sin'); assert(numel(sines) == 2);
for k = 1:2, set_param(sines{k},'SampleTime','plant_Ts','Frequency','2*pi*line_frequency'); end
set_param([model '/' sprintf('A\n\n')],'Frequency','line_frequency');
set_param([model '/B'],'Frequency','line_frequency');
set_param([model '/Controlled Voltage Source'],'Frequency','line_frequency','Amplitude','e*sqrt(2)');
set_param([model '/Vdc*'],'After',sprintf('%.17g',cfg.dc_reference));
cleanup = dpc_clean_recording_diagnostics(model);
chart_root = sfroot;
chart = chart_root.find('-isa','Stateflow.EMChart','Path',[model '/12_sector']); assert(numel(chart) == 1);
script = chart.Script;
assert(contains(script,'(alpha>-150 & alpha<=-120)') && contains(script,'(alpha>-60 & alpha<=-30)'));
chart.Script = strrep(strrep(script,'(alpha>-150 & alpha<=-120)', ...
    '(alpha>=-150 & alpha<=-120)'),'(alpha>-60 & alpha<=-30)','(alpha>=-60 & alpha<=-30)');
% Sample the ENTIRE controller, including sector selection, at the same Ts.
old_sector = input_source([model '/Subsystem1'],1);
sub = get_param([model '/Subsystem1'],'PortHandles'); delete_line(model,old_sector,sub.Inport(1));
add_block('simulink/Discrete/Zero-Order Hold',[model '/Sector_at_control_Ts'], ...
    'SampleTime','control_Ts','Position',[820,400,910,440]);
sector_ports = get_param([model '/Sector_at_control_Ts'],'PortHandles');
add_line(model,old_sector,sector_ports.Inport(1),'autorouting','on');
add_line(model,sector_ports.Outport(1),sub.Inport(1),'autorouting','on');
channels = cell(1,2); labels = {'dp','dq'};
for k = 1:2
    block = [model '/' labels{k}]; assert(strcmp(get_param(block,'BlockType'),'Relay'));
    on = str2double(get_param(block,'OnSwitchValue')); off = str2double(get_param(block,'OffSwitchValue'));
    assert(str2double(get_param(block,'OnOutputValue')) == 1 && str2double(get_param(block,'OffOutputValue')) == 0);
    set_param(block,'SampleTime','control_Ts');
    channels{k} = dpc3_channel_config(cfg,ts,on,off,~strcmp(method,'binary_limit'));
end
sources = {port([model '/From1']),port([model '/From']),port([model '/From7']), ...
    input_source([model '/Sum'],1),input_source([model '/Sum'],2), ...
    input_source([model '/Sum1'],1),input_source([model '/Sum1'],2),port([model '/Subsystem1'])};
if ~strcmp(method,'conventional')
    for k = 1:2
        param = ['dpc3_' labels{k} '_cfg']; assignin(ws,param,channels{k});
        target = [model '/Ternary_' labels{k}];
        add_block('built-in/M-S-Function',target,'FunctionName','dpc3_classifier_sfun', ...
            'Parameters',param,'Position',[1100,450+120*k,1290,510+120*k]);
        p = get_param(target,'PortHandles');
        add_line(model,input_source([model '/' labels{k}],1),p.Inport(1),'autorouting','on');
        add_line(model,port([model '/' labels{k}]),p.Inport(2),'autorouting','on');
    end
    table_cfg = dpc3_table_config(cfg,ts,channels{1},channels{2}); assignin(ws,'dpc3_table_cfg',table_cfg);
    add_block('built-in/M-S-Function',[model '/Nine_state_table'], ...
        'FunctionName','dpc3_table_sfun','Parameters','dpc3_table_cfg','Position',[1380,420,1620,810]);
    p = get_param([model '/Nine_state_table'],'PortHandles');
    inputs = [port([model '/Ternary_dp']),port([model '/Ternary_dq']),sector_ports.Outport(1), ...
        sources{2},sources{1},sources{3},sources{5},sources{7},port([model '/dp']),port([model '/dq'])];
    for k = 1:10, add_line(model,inputs(k),p.Inport(k),'autorouting','on'); end
    assignin(ws,'dpc3_enable',double(~strcmp(method,'bypass')));
    add_block('simulink/Sources/Constant',[model '/Enable_ternary'],'Value','dpc3_enable', ...
        'Position',[1670,425,1740,455]);
    add_block('simulink/Signal Routing/Switch',[model '/Bridge_gate_selector'], ...
        'Criteria','u2 > Threshold','Threshold','0.5','Position',[1810,470,1880,600]);
    select = get_param([model '/Bridge_gate_selector'],'PortHandles');
    add_line(model,p.Outport(1),select.Inport(1),'autorouting','on');
    add_line(model,port([model '/Enable_ternary']),select.Inport(2),'autorouting','on');
    add_line(model,sources{8},select.Inport(3),'autorouting','on');
    gates_goto = find_system(model,'SearchDepth',1,'BlockType','Goto','GotoTag','Gate');
    assert(numel(gates_goto) == 1); goto_ports = get_param(gates_goto{1},'PortHandles');
    assert(input_source(gates_goto{1},1) == sources{8});
    delete_line(model,sources{8},goto_ports.Inport(1));
    add_line(model,select.Outport(1),goto_ports.Inport(1),'autorouting','on');
    sources{8} = select.Outport(1);
    dpc3_add_log(model,'audit',p.Outport(2),ts,[1940,720,2140,760]);
end
names = {'iabc','vabc','vdc','p','pref','q','qref','gates'};
for k = 1:8
    dt = cfg.measurement_step; if k == 8, dt = cfg.plant_step; end
    dpc3_add_log(model,names{k},sources{k},dt,[2010,70+65*k,2220,110+65*k]);
end
dpc3_add_log(model,'binary_dp',port([model '/dp']),ts,[2300,600,2480,640]);
dpc3_add_log(model,'binary_dq',port([model '/dq']),ts,[2300,670,2480,710]);
dpc3_add_log(model,'sector',sector_ports.Outport(1),ts,[2300,740,2480,780]);
note = Simulink.Annotation(model,sprintf(['DPC3 %s | control Fs=%g Hz | sampled sector\n' ...
    'Ternary states feed the 9-state table directly. Binary corners = original table.\n' ...
    'Zero means target unchanged power; no PAM3 receiver/ADC/filter delay.'],method,fs));
note.Position = [50,850];
save_system(model,fullfile(root,'models',[model '.slx']));
info = struct('method',method,'control_hz',fs,'control_sample_time',ts,'channels',{channels}, ...
    'controller_drives_bridge',true,'true_ternary',strcmp(method,'proposed'), ...
    'switching_table_changed',~strcmp(method,'conventional'),'binary_corners_preserved',true, ...
    'sector_sampled_at_control_rate',true,'common_cleanup',{cleanup});
end
function p = port(block)
h = get_param(block,'PortHandles'); p = h.Outport(1);
end
function p = input_source(block,number)
h = get_param(block,'PortHandles'); l = get_param(h.Inport(number),'Line'); assert(l ~= -1);
p = get_param(l,'SrcPortHandle');
end
