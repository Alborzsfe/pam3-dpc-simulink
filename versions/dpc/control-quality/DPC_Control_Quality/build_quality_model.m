function [model, info] = build_quality_model(method, control_hz, cfg)
% Build a genuine closed-loop copy. The selected controller drives the bridge.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'), fullfile(root, 'patent_core'));
quality_validate_config(cfg);
assert(any(strcmp(method, {'conventional', 'proposed'})));
model = sprintf('Q_DPC_%s_%gk', method, control_hz/1000);
if bdIsLoaded(model)
    assert(strcmp(get_param(model, 'Dirty'), 'off'), 'QUALITY:Unsaved', ...
        'Save unsaved edits in %s before rebuilding it.', model);
    close_system(model, 0);
end
destination = fullfile(root, 'models', [model '.slx']);
if ~exist(fullfile(root,'models'),'dir'), mkdir(fullfile(root,'models')); end
copyfile(fullfile(root, 'source_model', 'DPC_POWER_RAHMAN_original.slx'), destination, 'f');
load_system(destination);
workspace = get_param(model, 'ModelWorkspace');
assignin(workspace, 'control_Ts', 1/control_hz);
assignin(workspace, 'plant_Ts', cfg.plant_step);
assignin(workspace, 'Ts', 1/control_hz);
assignin(workspace, 'e', cfg.phase_rms_voltage);
assignin(workspace, 'line_frequency', cfg.line_frequency);
set_param([model '/powergui'], 'SampleTime', 'plant_Ts', 'frequency', 'line_frequency');
% Preserve the continuous PI: ode3 supports its continuous state.
set_param(model, 'SolverType', 'Fixed-step', 'Solver', 'ode3', ...
    'FixedStep', 'plant_Ts', 'StartTime', '0', ...
    'StopTime', sprintf('%.17g', cfg.stop_time), 'SimulationMode', 'normal', ...
    'ReturnWorkspaceOutputs', 'on', 'SaveTime', 'off', 'SaveOutput', 'off', ...
    'SignalLogging', 'off');
% Both methods and both rates use identical physical source sampling.
sines = find_system([model '/Subsystem2'], 'SearchDepth', 1, 'BlockType', 'Sin');
assert(numel(sines) == 2, 'QUALITY:Source', 'Expected two phase-C sine sources.');
for k = 1:numel(sines)
    set_param(sines{k}, 'SampleTime', 'plant_Ts', 'Frequency', '2*pi*line_frequency');
end
set_param([model '/' sprintf('A\n\n')], 'Frequency', 'line_frequency');
set_param([model '/B'], 'Frequency', 'line_frequency');
set_param([model '/Controlled Voltage Source'], 'Frequency', 'line_frequency', ...
    'Amplitude', 'e*sqrt(2)');
set_param([model '/Vdc*'], 'After', sprintf('%.17g', cfg.dc_reference));
cleanup = dpc_clean_recording_diagnostics(model);
sector_note = patch_sector_boundaries(model);
controllers = cell(1, 2);
for channel = 1:2
    labels = {'dp', 'dq'}; path = [model '/' labels{channel}];
    assert(strcmp(get_param(path, 'BlockType'), 'Relay'));
    on_value = str2double(get_param(path, 'OnSwitchValue'));
    off_value = str2double(get_param(path, 'OffSwitchValue'));
    assert(str2double(get_param(path, 'OnOutputValue')) == 1 && ...
        str2double(get_param(path, 'OffOutputValue')) == 0);
    controllers{channel} = quality_controller_config(cfg, 1/control_hz, on_value, off_value);
    if strcmp(method, 'conventional')
        set_param(path, 'SampleTime', 'control_Ts');
    else
        handles = get_param(path, 'PortHandles');
        source_line = get_param(handles.Inport(1), 'Line');
        source = get_param(source_line, 'SrcPortHandle');
        output_line = get_param(handles.Outport(1), 'Line');
        destinations = get_param(output_line, 'DstPortHandle');
        position = get_param(path, 'Position');
        % Remove the input branch only; preserve other consumers of the error.
        delete_line(model, source, handles.Inport(1));
        delete_line(output_line);
        delete_block(path);
        parameter = ['quality_' labels{channel} '_cfg'];
        assignin(workspace, parameter, controllers{channel});
        add_block('built-in/M-S-Function', path, 'FunctionName', 'quality_controller_sfun', ...
            'Parameters', parameter, 'Position', position);
        handles = get_param(path, 'PortHandles');
        add_line(model, source, handles.Inport(1), 'autorouting', 'on');
        for j = 1:numel(destinations)
            add_line(model, handles.Outport(1), destinations(j), 'autorouting', 'on');
        end
    end
end
sources = {port([model '/From1']), port([model '/From']), ...
    port([model '/From7']), input_source([model '/Sum'], 1), ...
    input_source([model '/Sum'], 2), input_source([model '/Sum1'], 1), ...
    input_source([model '/Sum1'], 2), port([model '/Subsystem1'])};
names = {'iabc', 'vabc', 'vdc', 'p', 'pref', 'q', 'qref', 'gates'};
for k = 1:numel(names)
    step = cfg.measurement_step;
    if strcmp(names{k}, 'gates'), step = cfg.plant_step; end
    sink = [model '/Quality_Log_' names{k}];
    add_block('simulink/Sinks/To Workspace', sink, ...
        'VariableName', ['quality_log_' names{k}], 'SaveFormat', 'Structure With Time', ...
        'SampleTime', sprintf('%.17g', step), 'Decimation', '1', ...
        'MaxDataPoints', 'inf', 'Position', [1520, 70+65*k, 1750, 115+65*k]);
    handles = get_param(sink, 'PortHandles');
    add_line(model, sources{k}, handles.Inport(1), 'autorouting', 'on');
end
note = Simulink.Annotation(model, sprintf(['CLOSED-LOOP %s | control Fs=%.6g Hz | plant step=%.6g s\n' ...
    'Proposed variant: %s. Same plant, PI, initial conditions and binary switching table.\n' ...
    'Control Fs is not the variable semiconductor switching frequency.'], ...
    method, control_hz, cfg.plant_step, cfg.proposed_variant));
note.Position = [50, 815];
save_system(model, destination);
info = struct('method', method, 'control_hz', control_hz, 'control_sample_time', 1/control_hz, ...
    'plant_step', cfg.plant_step, 'measurement_step', cfg.measurement_step, ...
    'controllers', {controllers}, 'common_cleanup', {cleanup}, ...
    'sector_boundary_patch', sector_note, 'controller_drives_bridge', true, ...
    'switching_table_changed', false, 'source_sines_resampled_to_plant_step', true, ...
    'phase_C_initialization_synchronized', true);
end

function p = port(block)
handles = get_param(block, 'PortHandles'); p = handles.Outport(1);
end

function p = input_source(block, number)
handles = get_param(block, 'PortHandles'); line = get_param(handles.Inport(number), 'Line');
assert(line ~= -1); p = get_param(line, 'SrcPortHandle');
end

function note = patch_sector_boundaries(model)
% Original inequalities leave gaps exactly at -150 and -60 degrees.
stateflow_root = sfroot;
chart = stateflow_root.find('-isa', 'Stateflow.EMChart', 'Path', [model '/12_sector']);
assert(numel(chart) == 1, 'QUALITY:SectorChart', 'Cannot locate the source sector function.');
script = chart.Script;
old_a = '(alpha>-150 & alpha<=-120)'; new_a = '(alpha>=-150 & alpha<=-120)';
old_b = '(alpha>-60 & alpha<=-30)'; new_b = '(alpha>=-60 & alpha<=-30)';
assert(contains(script, old_a) && contains(script, old_b), 'QUALITY:SectorSource', ...
    'Sector function differs from supplied source. Review before applying the common patch.');
script = strrep(script, old_a, new_a); script = strrep(script, old_b, new_b);
chart.Script = script;
note = 'Closed the original sector-index gaps at -150 and -60 degrees, identically in all runs.';
end
