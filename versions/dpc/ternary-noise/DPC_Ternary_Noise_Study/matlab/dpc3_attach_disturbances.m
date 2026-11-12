function ports = dpc3_attach_disturbances(model,cfg,s,stimulus)
ws = get_param(model,'ModelWorkspace');
assignin(ws,'dpc3_noise_array',stimulus.noise_array);
assignin(ws,'dpc3_noise_Ts',cfg.noise_sample_time);
vraw = output_port([model '/From']); iraw = output_port([model '/From1']);
% Copy the SAME original power calculator for truth monitoring. NEVER feeds control.
monitor = [model '/True_power_monitor'];
add_block([model '/Subsystem'],monitor,'Position',[50,1000,220,1140]);
p = get_param(monitor,'PortHandles');
add_line(model,vraw,p.Inport(1),'autorouting','on');
add_line(model,iraw,p.Inport(2),'autorouting','on');
add_block('simulink/Sinks/Terminator',[model '/Unused_true_angle'],'Position',[280,1000,300,1020]);
tp = get_param([model '/Unused_true_angle'],'PortHandles');add_line(model,p.Outport(1),tp.Inport(1));
ports.p_true = p.Outport(2); ports.q_true = p.Outport(3);
add_block('simulink/Sources/From Workspace',[model '/Shared_sensor_noise'], ...
    'VariableName','dpc3_noise_array','SampleTime','dpc3_noise_Ts','Interpolate','off', ...
    'OutputAfterFinalValue','Holding final value','Position',[40,1200,240,1250]);
add_block('simulink/Signal Routing/Demux',[model '/Noise_channels'], ...
    'Outputs','[3 1 1]','Position',[290,1180,300,1300]);
np = get_param([model '/Noise_channels'],'PortHandles');
add_line(model,output_port([model '/Shared_sensor_noise']),np.Inport(1));
ports.v_feedback = add_sum(model,'Voltage_sensor',vraw,np.Outport(1),[360,1170,415,1220]);
replace_input(model,[model '/Subsystem'],1,ports.v_feedback);
power_calc = get_param([model '/Subsystem'],'PortHandles');
ports.p_feedback = add_sum(model,'Power_sensor_P',power_calc.Outport(2),np.Outport(2),[470,1250,525,1300]);
ports.q_feedback = add_sum(model,'Power_sensor_Q',power_calc.Outport(3),np.Outport(3),[470,1340,525,1390]);
pg = find_system(model,'SearchDepth',1,'BlockType','Goto','GotoTag','P');
qg = find_system(model,'SearchDepth',1,'BlockType','Goto','GotoTag','Q');
assert(numel(pg) == 1 && numel(qg) == 1);
replace_input(model,pg{1},1,ports.p_feedback); replace_input(model,qg{1},1,ports.q_feedback);
add_block('simulink/Signal Routing/Mux',[model '/Measured_power_pair'], ...
    'Inputs','2','Position',[610,1260,620,1380]);
mp = get_param([model '/Measured_power_pair'],'PortHandles');
add_line(model,ports.p_feedback,mp.Inport(1)); add_line(model,ports.q_feedback,mp.Inport(2));
ports.measured_power = mp.Outport(1);
% Noise logs are sampled at the SENSOR clock, independent of controller Fs.
names = {'noise_vabc','noise_p','noise_q'};
for k = 1:3
    dpc3_add_log(model,names{k},np.Outport(k),cfg.noise_sample_time,[700,1150+70*k,900,1190+70*k]);
end
ports.grid_distorted = any([s.h5_pu,s.h7_pu,s.ripple_pu] ~= 0);
if ports.grid_distorted
    add_block('simulink/Sources/Clock',[model '/Grid_disturbance_clock'],'Position',[50,1480,80,1510]);
    add_block('simulink/Signal Routing/Mux',[model '/Grid_delta_abc'],'Inputs','3','Position',[740,1510,750,1690]);
    gp = get_param([model '/Grid_delta_abc'],'PortHandles');
    sources = {[model '/' sprintf('A\n\n')],[model '/B'],[model '/Controlled Voltage Source']};
    measurement = get_param([model '/' sprintf('Three-Phase\nV-I Measurement')],'PortHandles');
    for phase = 1:3
        fcn = [model sprintf('/Grid_delta_phase_%d',phase)];
        add_block('simulink/User-Defined Functions/Fcn',fcn, ...
            'Expr',dpc3_grid_expression(cfg,s,phase),'Position',[160,1460+80*phase,450,1500+80*phase]);
        fp = get_param(fcn,'PortHandles');
        add_line(model,output_port([model '/Grid_disturbance_clock']),fp.Inport(1));
        add_line(model,fp.Outport(1),gp.Inport(phase));
        % Add an independent SERIES voltage; keep the original three sources.
        series = [model sprintf('/Grid_series_phase_%d',phase)];
        add_block([model '/Controlled Voltage Source'],series,'Initialize','off', ...
            'Measurements','None','Position',[470+80*phase,1540,510+80*phase,1570]);
        sp = get_param(series,'PortHandles'); old = get_param(sources{phase},'PortHandles');
        assert(numel(old.RConn) == 1 && numel(sp.LConn) == 1 && numel(sp.RConn) == 1);
        delete_line(model,old.RConn(1),measurement.LConn(phase));
        add_line(model,old.RConn(1),sp.LConn(1),'autorouting','on');
        add_line(model,sp.RConn(1),measurement.LConn(phase),'autorouting','on');
        add_line(model,fp.Outport(1),sp.Inport(1),'autorouting','on');
    end
    grid_port = gp.Outport(1);
else
    add_block('simulink/Sources/Constant',[model '/Grid_delta_zero'], ...
        'Value','[0;0;0]','Position',[50,1480,120,1520]);
    grid_port = output_port([model '/Grid_delta_zero']);
end
extra_names = {'v_feedback','p_feedback','q_feedback','grid_delta'};
extra_ports = [ports.v_feedback,ports.p_feedback,ports.q_feedback,grid_port];
for k = 1:numel(extra_names)
    dpc3_add_log(model,extra_names{k},extra_ports(k),cfg.measurement_step,[1000,1120+70*k,1220,1160+70*k]);
end
end
function p = output_port(block)
h = get_param(block,'PortHandles'); p = h.Outport(1);
end
function p = add_sum(model,name,a,b,position)
block = [model '/' name];
add_block('simulink/Math Operations/Sum',block,'Inputs','++','Position',position);
h = get_param(block,'PortHandles'); add_line(model,a,h.Inport(1),'autorouting','on');
add_line(model,b,h.Inport(2),'autorouting','on'); p = h.Outport(1);
end
function replace_input(model,block,index,source)
h = get_param(block,'PortHandles'); line = get_param(h.Inport(index),'Line');
assert(line ~= -1); old = get_param(line,'SrcPortHandle');
delete_line(model,old,h.Inport(index)); add_line(model,source,h.Inport(index),'autorouting','on');
end
