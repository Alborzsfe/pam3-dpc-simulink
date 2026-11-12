function changes = dpc_clean_recording_diagnostics(model)
% Measurement-only cleanup in the recording COPY; gate paths are untouched.
changes = {};
for name = {'Demux', 'Demux1'}
    block = [model '/Subsystem/' name{1}];
    ports = get_param(block, 'PortHandles');
    if numel(ports.Outport) >= 3 && get_param(ports.Outport(3), 'Line') == -1
        position = get_param(block, 'Position');
        sink = [model '/Subsystem/Unused_' name{1} '_Third_Output'];
        add_block('simulink/Sinks/Terminator', sink, ...
            'Position', [position(3)+75, position(4)+30, position(3)+95, position(4)+50]);
        destination = get_param(sink, 'PortHandles');
        add_line([model '/Subsystem'], ports.Outport(3), destination.Inport(1), 'autorouting', 'on');
        changes{end+1} = ['Terminated unused third output of ' name{1}]; %#ok<AGROW>
    end
end
system = [model '/Subsystem1/Switching frequency '];
clock_ports = get_param([system '/Clock'], 'PortHandles');
divide = get_param([system '/Divide'], 'PortHandles');
% This is a read-only frequency monitor: 0.5 * switch_count / elapsed_time.
% At t=0, choose a nonzero denominator; for every t>0, preserve original t.
delete_line(system, clock_ports.Outport(1), divide.Inport(2));
add_block('simulink/Sources/Constant', [system '/Initial_Denominator'], ...
    'Value', '1', 'Position', [40, 265, 80, 295]);
add_block('simulink/Signal Routing/Switch', [system '/Guard_Initial_Time'], ...
    'Criteria', 'u2 > Threshold', 'Threshold', '0', ...
    'Position', [155, 240, 205, 300]);
constant = get_param([system '/Initial_Denominator'], 'PortHandles');
guard = get_param([system '/Guard_Initial_Time'], 'PortHandles');
add_line(system, clock_ports.Outport(1), guard.Inport(1), 'autorouting', 'on');
add_line(system, clock_ports.Outport(1), guard.Inport(2), 'autorouting', 'on');
add_line(system, constant.Outport(1), guard.Inport(3), 'autorouting', 'on');
add_line(system, guard.Outport(1), divide.Inport(2), 'autorouting', 'on');
changes{end+1} = 'Frequency-monitor denominator guarded at t=0; original formula retained at t>0.';
end
