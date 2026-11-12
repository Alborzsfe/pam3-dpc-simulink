function model = build_simulink_comparison(cfg)
% Rebuild the draft using native Simulink APIs in the user's MATLAB R2024b.
root = fileparts(mfilename('fullpath'));
addpath(root, fullfile(root, 'simulink'), fullfile(root, 'PAM3_original'));
if nargin < 1
    cfg = comparison_config();
end
% Do not use exist('new_system','file'): it excludes built-in functions.
% Loading the library below is the real Simulink availability check.
spec = jsondecode(fileread(fullfile(root, 'tools', 'model_graph.json')));
model = spec.model;
load_system('simulink');
if bdIsLoaded(model)
    assert(strcmp(get_param(model, 'Dirty'), 'off'), 'SimpleSim:UnsavedModel', ...
        'Save your model edits before rebuilding, or close the model first.');
    close_system(model, 0);
end
new_system(model);
try
set_param(model, 'SolverType', 'Fixed-step', 'Solver', 'FixedStepDiscrete', ...
    'FixedStep', 'simple_ts', 'StartTime', '0', 'StopTime', 'simple_stop_time', ...
    'SimulationMode', 'normal', 'ReturnWorkspaceOutputs', 'on', ...
    'SaveTime', 'on', 'TimeSaveName', 'simple_time', 'SaveFormat', 'Array', ...
    'SaveOutput', 'off', 'SignalLogging', 'off', 'SaveState', 'off', ...
    'LimitDataPoints', 'off');
prepare_simulink_comparison(model, cfg);
build_system_graph(model, 'root', spec);
set_param(model, 'PostLoadFcn', spec.callback, 'InitFcn', spec.callback);
save_system(model, fullfile(root, 'models', [model '.slx']));
open_system(model);
set_param(model, 'ZoomFactor', 'FitSystem');
fprintf('Native model saved: models/%s.slx\n', model);
catch err
    % Close only the incomplete model created by this invocation.
    % Previously loaded unsaved models are protected by the guard above.
    if bdIsLoaded(model)
        close_system(model, 0);
    end
    rethrow(err);
end
end

function build_system_graph(path, key, spec)
ids = {spec.systems.id};
system = spec.systems(strcmp(ids, key));
assert(isscalar(system));
for k = 1:numel(system.blocks)
    b = system.blocks(k);
    destination = [path '/' b.name];
    block_args = {'Position', double(b.position(:)')};
    names = fieldnames(b.params);
    for j = 1:numel(names)
        name = names{j};
        % Appearance must not prevent a model from being built. This also
        % accepts older copies of the graph containing unsupported colors.
        if strcmp(name, 'BackgroundColor')
            continue;
        end
        block_args(end+1:end+2) = {name, b.params.(name)}; %#ok<AGROW>
    end
    % Supply FunctionName AND Parameters in the SAME creation call.
    % Setting FunctionName alone can immediately initialize an S-function
    % while its dialog-parameter list is still empty.
    add_block(b.source, destination, block_args{:});
    if ~isempty(b.subsystem)
        % A native subsystem can contain default In1/Out1 blocks and a line.
        % Remove these before adding the explicit ports in our graph.
        Simulink.SubSystem.deleteContents(destination);
        build_system_graph(destination, b.subsystem, spec);
    end
end
for k = 1:numel(system.lines)
    edge = system.lines(k);
    source = sprintf('%s/%d', edge.src, edge.srcPort);
    dest = sprintf('%s/%d', edge.dst, edge.dstPort);
    add_line(path, source, dest, 'autorouting', 'on');
end
for k = 1:numel(system.notes)
    note = system.notes(k);
    annotation = Simulink.Annotation(path, note.text);
    annotation.Position = double(note.position(:)');
end
end
