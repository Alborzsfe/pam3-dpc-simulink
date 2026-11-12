function report = validate_quality_simulink()
% Native S-function preflight with independent fixtures; NOT a converter run.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root,'matlab'), fullfile(root,'patent_core'));
fixtures = load(fullfile(root,'data','quality_fixtures.mat'));
model = 'quality_controller_preflight';
if bdIsLoaded(model)
    assert(strcmp(get_param(model,'Dirty'),'off'), 'Save/close the existing preflight model first.');
    close_system(model,0);
end
new_system(model); close_model = onCleanup(@() close_system(model,0));
% add_block evaluates the S-function dialog parameter immediately. Populate
% the MODEL workspace before creating any blocks that refer to these names.
workspace = get_param(model,'ModelWorkspace');
selected = [7,8,17,18,27,28,37,38]; samples = 0;
initial_item = fixtures.cases{selected(1)};
initial_cfg = quality_config(); initial_cfg.proposed_variant = strtrim(initial_item.variant);
initial_controller = quality_controller_config(initial_cfg,1/initial_item.fs,1,-1);
% Use the same two-column input format as the user's validated PAM3 model.
% All time values use integer multiples of the identical controller period.
initial_input = quality_fixture_input(initial_item.errors,initial_controller.sample_time);
assignin(workspace,'quality_input',initial_input);
assignin(workspace,'quality_Ts',1/initial_item.fs);
assignin(workspace,'quality_test_cfg',initial_controller);
add_block('simulink/Sources/From Workspace',[model '/Errors'], ...
    'VariableName','quality_input','Interpolate','off','SampleTime','quality_Ts', ...
    'OutputAfterFinalValue','Holding final value');
add_block('built-in/M-S-Function',[model '/Proposed'], ...
    'FunctionName','quality_controller_sfun','Parameters','quality_test_cfg');
add_block('simulink/Sinks/To Workspace',[model '/Logged'], ...
    'VariableName','quality_output','SaveFormat','Structure With Time', ...
    'SampleTime','quality_Ts','MaxDataPoints','inf');
add_block('simulink/Sinks/To Workspace',[model '/InputLogged'], ...
    'VariableName','quality_input_seen','SaveFormat','Structure With Time', ...
    'SampleTime','quality_Ts','MaxDataPoints','inf');
add_line(model,'Errors/1','Proposed/1'); add_line(model,'Proposed/1','Logged/1');
add_line(model,'Errors/1','InputLogged/1');
set_param(model,'SolverType','Fixed-step','Solver','FixedStepDiscrete', ...
    'FixedStep','quality_Ts','ReturnWorkspaceOutputs','on', ...
    'SaveTime','off','SaveOutput','off');
for k = selected
    item = fixtures.cases{k}; cfg = quality_config(); cfg.proposed_variant = strtrim(item.variant);
    controller = quality_controller_config(cfg,1/item.fs,1,-1);
    input_data = quality_fixture_input(item.errors,controller.sample_time);
    time = input_data(:,1);
    assignin(workspace,'quality_input',input_data);
    assignin(workspace,'quality_Ts',1/item.fs);
    assignin(workspace,'quality_test_cfg',controller);
    set_param(model,'StopTime',sprintf('%.17g',time(end)));
    raw_output = []; raw_input = [];
    try
        out = sim(model,'ReturnWorkspaceOutputs','on');
        raw_output = out.get('quality_output'); raw_input = out.get('quality_input_seen');
        % Never resample a same-rate validation trace using strict previous-ZOH:
        % roundoff at a sample boundary can select the previous sample.
        actual = quality_discrete_samples(raw_output,controller.sample_time,numel(item.errors),'output');
        observed_input = quality_discrete_samples(raw_input,controller.sample_time,numel(item.errors),'input');
        input_mismatch = find(observed_input ~= double(item.errors(:)));
        output_mismatch = find(actual ~= double(item.expected(:)));
        assert(isempty(input_mismatch),'QUALITY:NativeInput', ...
            'Fixture %d: %d loaded-input mismatches; first sample %d.', ...
            k,numel(input_mismatch),first_or_zero(input_mismatch));
        assert(isempty(output_mismatch),'QUALITY:NativeGolden', ...
            'Fixture %d: %d controller mismatches; first sample %d (one-based).', ...
            k,numel(output_mismatch),first_or_zero(output_mismatch));
    catch exception
        failure = struct('fixture',k,'item',item,'controller',controller, ...
            'input_array',input_data,'raw_output',raw_output,'raw_input',raw_input, ...
            'identifier',exception.identifier,'message',exception.message,'runtime',version);
        failure_file = fullfile(root,'validation','native_preflight_failure.mat');
        save(failure_file,'failure','-v7');
        fprintf('Native preflight diagnostics saved: %s\n',failure_file);
        rethrow(exception);
    end
    samples = samples+numel(actual);
end

report = struct('passed',true,'simulink_executed',true,'converter_executed',false, ...
    'cases',numel(selected),'samples',samples,'runtime',version, ...
    'input_format','two-column double array','sample_comparison','exact indexed clock-checked values');
save(fullfile(root,'validation','native_controller_report.mat'),'report');
fprintf('PASS actual Simulink controller: %d cases, %d samples. Converter study follows.\n', ...
    report.cases,report.samples);
end

function first = first_or_zero(indices)
first = 0; if ~isempty(indices), first = indices(1); end
end
