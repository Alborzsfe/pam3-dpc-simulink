function report = validate_dpc_simulink()
% Execute all replay routes in actual Simulink against independent fixtures.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'), fullfile(root, 'patent_core'));
data = load(fullfile(root, 'data', 'comparison_fixtures.mat'));
cases_checked = 0; samples = 0; symbols = 0;
selected = {'constant_zero', 'constant_positive', 'constant_negative', ...
    'exact_boundaries', 'plateau_return', 'clipping', 'pulse_width_1', ...
    'pulse_width_2', 'pulse_width_3', 'noisy_4', 'asymmetric_band'};
for k = 1:numel(data.cases)
    c = data.cases{k};
    if ~any(strcmp(c.name, selected)), continue; end
    cfg = dpc_config(); cfg.patent_mode = c.mode;
    cfg.release_ratio = c.ratio; cfg.relay_on(:) = c.on; cfg.relay_off(:) = c.off;
    x = double(c.error(:)); n = numel(x);
    capture = struct('time', (0:n-1)'*cfg.sample_time, 'errors', [x,x], ...
        'kind', 'synthetic_fixture');
    dpc_prepare_replay_inputs(capture, cfg);
    build_dpc_replay_model(cfg);
    out = sim('dpc_same_input_comparison', 'ReturnWorkspaceOutputs', 'on');
    for channel = 1:2
        label = cfg.channels{channel};
        b = out.get(['dpc_binary_' label]); z = out.get(['dpc_ternary_' label]);
        p = out.get(['dpc_patent_' label]);
        binary = reshape(double(b.signals.values), [], 1);
        ternary = reshape(double(z.signals.values), [], 1);
        assert(isequal(binary(1:n), double(c.binary(:))), 'DPC:SimulinkRelay', ...
            'Native Relay fixture failed: %s.', c.name);
        assert(isequal(ternary(1:n), double(c.ternary(:))), 'DPC:SimulinkTernary', ...
            'Native ternary fixture failed: %s.', c.name);
        patent = pam3_trace_decode(reshape(double(p.signals.values), [], 18));
        for name = {'raw_levels', 'levels', 'points', 'symbols', 'thresholds'}
            field = name{1}; expected_field = field;
            if strcmp(field, 'raw_levels'), expected_field = 'raw'; end
            assert(isequal(patent.(field), double(c.(expected_field))), ...
                'DPC:SimulinkPatent', 'Patent fixture failed: %s / %s.', c.name, field);
        end
        cases_checked = cases_checked+1; samples = samples+n;
        symbols = symbols+numel(c.symbols);
    end
end
report = struct('passed', true, 'simulink_executed', true, 'converter_executed', false, ...
    'channel_cases_checked', cases_checked, 'error_samples_checked', samples, ...
    'patent_symbols_checked', symbols, 'runtime', version, ...
    'reference', 'Saved independent Python fixtures');
save(fullfile(root, 'validation', 'simulink_replay_validation.mat'), 'report', '-v7');
fprintf('PASS actual Simulink comparison: %d channel cases, %d error samples.\n', cases_checked, samples);
end
