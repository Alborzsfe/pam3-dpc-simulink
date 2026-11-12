function [capture, cfg] = record_dpc_errors(cfg)
% Instrument a COPY. Existing converter decision/gate paths are preserved.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'), fullfile(root, 'patent_core'));
if nargin == 0, cfg = dpc_config(); end
source = fullfile(root, 'source_model', 'DPC_POWER_RAHMAN_original.slx');
model = 'DPC_PAM3_recording';
if bdIsLoaded(model)
    assert(strcmp(get_param(model, 'Dirty'), 'off'), 'DPC:UnsavedModel', ...
        'Save your changes to DPC_PAM3_recording before running again.');
    close_system(model, 0);
end
destination = fullfile(root, 'models', [model '.slx']);
copyfile(source, destination, 'f');
load_system(destination);
assumptions = {};
parameters = struct();
defaults = struct('Ts', cfg.fallback_Ts, 'e', cfg.fallback_e);
for name = {'Ts', 'e'}
    key = name{1};
    if evalin('base', ['exist(''' key ''',''var'')'])
        parameters.(key) = evalin('base', key);
    else
        parameters.(key) = defaults.(key);
        assumptions{end+1} = sprintf('%s absent from source/workspace: EXAMPLE value %.12g used.', ...
            key, parameters.(key)); %#ok<AGROW>
        fprintf('EXPLICIT BENCHMARK ASSUMPTION: %s\n', assumptions{end});
    end
    assert(isscalar(parameters.(key)) && isnumeric(parameters.(key)) && ...
        isfinite(parameters.(key)) && parameters.(key) > 0, ...
        'DPC:Parameters', 'Ts and e must be finite positive scalars.');
end
cfg.sample_time = double(parameters.Ts);
for channel = 1:2
    detector = [model '/d' lower(cfg.channels{channel})];
    assert(strcmp(get_param(detector, 'BlockType'), 'Relay'));
    % All four values in the supplied model are numeric literals/defaults.
    cfg.relay_on(channel) = str2double(get_param(detector, 'OnSwitchValue'));
    cfg.relay_off(channel) = str2double(get_param(detector, 'OffSwitchValue'));
    cfg.relay_output_on(channel) = str2double(get_param(detector, 'OnOutputValue'));
    cfg.relay_output_off(channel) = str2double(get_param(detector, 'OffOutputValue'));
end
dpc_validate_config(cfg);
% Store parameters in the recording COPY so it can be reopened for review.
% Do not place assumed values into the user's base workspace.
model_workspace = get_param(model, 'ModelWorkspace');
assignin(model_workspace, 'Ts', parameters.Ts);
assignin(model_workspace, 'e', parameters.e);
measurement_cleanup = dpc_clean_recording_diagnostics(model);
% Sources are found through the actual wired ports, not guessed signal names.
dp_error = input_source([model '/dp'], 1);
dq_error = input_source([model '/dq'], 1);
p_sum = get_param(dp_error, 'Parent'); q_sum = get_param(dq_error, 'Parent');
ports = {dp_error, dq_error, output_port([model '/dp']), output_port([model '/dq']), ...
    input_source(p_sum, 1), input_source(p_sum, 2), ...
    input_source(q_sum, 1), input_source(q_sum, 2), ...
    output_port([model '/12_sector']), output_port([model '/Subsystem1'])};
names = {'ep', 'eq', 'dp', 'dq', 'p', 'pref', 'q', 'qref', 'sector', 'gates'};
for k = 1:numel(names)
    sink = [model '/Compare_Log_' names{k}];
    add_block('simulink/Sinks/To Workspace', sink, ...
        'VariableName', ['dpc_logged_' names{k}], ...
        'SaveFormat', 'Structure With Time', 'SampleTime', '-1', ...
        'MaxDataPoints', 'inf', 'Decimation', '1', ...
        'Position', [1510, 55+65*k, 1730, 100+65*k]);
    sink_ports = get_param(sink, 'PortHandles');
    add_line(model, ports{k}, sink_ports.Inport(1), 'autorouting', 'on');
end
set_param(model, 'ReturnWorkspaceOutputs', 'on', ...
    'StopTime', sprintf('%.17g', cfg.converter_stop_time), ...
    'MaxStep', sprintf('%.17g', cfg.sample_time));
save_system(model, destination);
input = Simulink.SimulationInput(model);
input = input.setVariable('Ts', parameters.Ts, 'Workspace', model);
input = input.setVariable('e', parameters.e, 'Workspace', model);
input = input.setModelParameter('StopTime', sprintf('%.17g', cfg.converter_stop_time), ...
    'MaxStep', sprintf('%.17g', cfg.sample_time), 'SimulationMode', 'normal', ...
    'ReturnWorkspaceOutputs', 'on');
fprintf('Running converter for %.6g s; Ts=%.6g s, e=%.6g V RMS.\n', ...
    cfg.converter_stop_time, parameters.Ts, parameters.e);
% Errors here are surfaced; no silent substitution by a synthetic waveform.
simout = sim(input);
raw = struct();
for k = 1:numel(names)
    raw.(names{k}) = simout.get(['dpc_logged_' names{k}]);
end
% Keep the completed simulation logs even if later processing raises an error.
folder = fullfile(root, 'results', 'actual_converter');
if ~exist(folder, 'dir'), mkdir(folder); end
save(fullfile(folder, 'dpc_capture_native.mat'), 'raw', 'cfg', ...
    'parameters', 'assumptions', 'measurement_cleanup', '-v7');
capture = dpc_uniform_capture(raw, cfg);
if ~isempty(capture.single_timestamp_signals_held)
    fprintf('Held single-timestamp signals: %s\n', ...
        strjoin(capture.single_timestamp_signals_held, ', '));
end
capture.kind = 'actual_converter';
capture.converter_executed = true;
capture.parameters = parameters;
capture.parameter_assumptions = assumptions;
capture.source_model = 'DPC_POWER_RAHMAN_original.slx';
capture.runtime = version;
capture.converter_stop_time = cfg.converter_stop_time;
capture.max_solver_step = cfg.sample_time;
capture.gate_table_modified = false;
capture.measurement_only_cleanup = measurement_cleanup;
save(fullfile(folder, 'dpc_capture.mat'), 'capture', 'cfg', '-v7');
fprintf('Recorded %d common error samples per channel.\n', numel(capture.time));
end

function port = input_source(block, number)
handles = get_param(block, 'PortHandles');
line = get_param(handles.Inport(number), 'Line');
assert(line ~= -1, 'DPC:Wiring', 'Required converter input is disconnected.');
port = get_param(line, 'SrcPortHandle');
end

function port = output_port(block)
handles = get_param(block, 'PortHandles');
port = handles.Outport(1);
end
