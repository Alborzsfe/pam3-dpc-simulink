function report = validate_simulink()
% Actual Simulink execution against saved INDEPENDENT Python fixtures.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab')); addpath(fullfile(root, 'models'));
fixture = load(fullfile(root, 'data', 'golden_cases.mat'));
build_pam3_models();
captures = 0; symbols = 0;
selected = {'empty', 'tail_1', 'tail_13', 'strict_thresholds', 'width_1_2_3', 'pam3_snr_32'};
for mode = [0, 1, 2]
    for dc_enabled = 0:1
        if mode == 2 && dc_enabled
            continue;
        end
        for n = 1:numel(selected)
            pair = cell(1, 2);
            for k = 1:numel(fixture.cases)
                c = fixture.cases{k};
                if strcmp(c.name, selected{n}) && c.adaptive_mode == mode && c.dc_enabled == dc_enabled
                    pair{c.channel+1} = c;
                end
            end
            cfg = pam3_config(); cfg.dc_enabled = logical(dc_enabled); cfg.adaptive_mode = mode;
            pam3_assign_inputs(pair{1}.adc, pair{2}.adc, cfg);
            simout = sim('pam3_patent_demo', 'ReturnWorkspaceOutputs', 'on');
            logs = {simout.get('trace_master'), simout.get('trace_slave')};
            for channel = 1:2
                actual = pam3_trace_decode(reshape(logs{channel}.signals.values, [], 18));
                c = pair{channel};
                names = {'corrected', 'raw_levels', 'levels', 'points', 'symbols'};
                for j = 1:numel(names)
                    f = names{j};
                    assert(isequal(actual.(f)(:), double(c.(f)(:))), ...
                        'PAM3:SimulinkFixture', 'Simulink mismatch: %s, %s.', c.name, f);
                end
                assert(isequal(actual.thresholds, double(c.thresholds)));
                captures = captures + 1; symbols = symbols + numel(actual.symbols);
            end
        end
    end
end
report = struct('passed', true, 'simulink_executed', true, ...
    'captures_checked', captures, 'symbols_checked', symbols, ...
    'runtime', version, 'reference', 'Saved independent Python fixtures');
save(fullfile(root, 'results', 'simulink_validation.mat'), 'report', '-v7');
fprintf('PASS actual Simulink: %d channel captures, %d symbols.\n', captures, symbols);
end
