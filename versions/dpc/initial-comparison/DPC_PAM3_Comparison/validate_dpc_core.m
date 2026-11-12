function report = validate_dpc_core()
% Actual .m execution against saved INDEPENDENT Python test fixtures.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'), fullfile(root, 'patent_core'));
data = load(fullfile(root, 'data', 'comparison_fixtures.mat'));
checked = 0; samples = 0; symbols = 0;
for k = 1:numel(data.cases)
    c = data.cases{k}; cfg = dpc_config();
    cfg.patent_mode = c.mode; cfg.release_ratio = c.ratio;
    cfg.relay_on(:) = c.on; cfg.relay_off(:) = c.off;
    x = double(c.error(:)); t = (0:numel(x)-1)'*cfg.sample_time;
    capture = struct('time', t, 'errors', [x, -x], 'kind', 'synthetic_fixture');
    result = dpc_compare_core(capture, cfg); actual = result.channels{1};
    fields = {'binary', 'ternary', 'adc', 'raw'};
    for j = 1:numel(fields)
        name = fields{j};
        assert(isequal(actual.(name)(:), double(c.(name)(:))), ...
            'DPC:CoreFixture', 'Mismatch in %s / %s / mode %d.', c.name, name, c.mode);
    end
    fields = {'levels', 'points', 'symbols', 'thresholds'};
    for j = 1:numel(fields)
        name = fields{j};
        assert(isequal(actual.patent.(name), double(c.(name))), ...
            'DPC:PatentFixture', 'Patent mismatch in %s / %s.', c.name, name);
    end
    assert(all(abs(actual.symbol_latency_s-20*cfg.sample_time) < 1e-12));
    % Both methods see the same original error vector; no look-ahead adapter.
    assert(isequal(actual.error, x) && result.same_input_assertion);
    checked = checked+1; samples = samples+numel(x); symbols = symbols+numel(c.symbols);
end
report = struct('passed', true, 'cases_checked', checked, ...
    'independent_error_samples_checked', samples, 'patent_symbols_checked', symbols, ...
    'runtime', version, 'reference', 'Saved independent Python fixtures', ...
    'simulink_executed', false, 'converter_executed', false);
save(fullfile(root, 'validation', 'core_validation.mat'), 'report', '-v7');
fprintf('PASS core: %d cases, %d independent error samples, %d patent symbols.\n', ...
    checked, samples, symbols);
end
