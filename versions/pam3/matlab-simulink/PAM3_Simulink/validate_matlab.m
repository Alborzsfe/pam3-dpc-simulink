function report = validate_matlab(quick)
% Compare actual .m execution with independent Python-produced fixtures.
if nargin < 1
    quick = true;
end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'));
fixture = load(fullfile(root, 'data', 'golden_cases.mat'));
cases = fixture.cases;
checked = 0; samples = 0; symbols = 0;
started = tic;
names = {'empty', 'tail_1', 'tail_2', 'tail_3', 'tail_4', ...
    'tail_11', 'tail_12', 'tail_13', 'tail_31', 'tail_32', 'tail_33', ...
    'strict_thresholds', 'width_1_2_3', 'random_128', 'pam3_snr_32'};
for k = 1:numel(cases)
    c = cases{k};
    if quick && ~any(strcmp(c.name, names))
        continue;
    end
    cfg = pam3_config();
    cfg.dc_enabled = logical(c.dc_enabled);
    cfg.adaptive_mode = c.adaptive_mode;
    actual = pam3_decode(c.adc, cfg);
    fields = {'corrected', 'raw_levels', 'levels', 'points', 'symbols'};
    for j = 1:numel(fields)
        f = fields{j};
        assert(isequal(actual.(f)(:), double(c.(f)(:))), ...
            'PAM3:Mismatch', 'Mismatch: %s, channel %d, DC %d, mode %d, %s.', ...
            c.name, c.channel, c.dc_enabled, c.adaptive_mode, f);
    end
    assert(isequal(actual.thresholds, double(c.thresholds)), ...
        'PAM3:ThresholdMismatch', 'Threshold mismatch: %s.', c.name);
    assert(actual.final_state(1) == numel(c.adc) + 20);
    checked = checked + 1; samples = samples + numel(c.adc);
    symbols = symbols + numel(c.symbols);
end

% Idle gaps must not change sample indices, and reset discards history.
cfg = pam3_config(); x = [127; 194; 194; 150; 60; 60; 100; 127];
a = pam3_decode(x, cfg); s = pam3_initial_state(cfg); trace = zeros(numel(x)+20, 18);
for k = 1:numel(x)
    [s, out] = pam3_step(s, x(k), 1, cfg); trace(k, :) = out';
    prior = s;
    [s, out] = pam3_step(s, 0, 0, cfg);
    assert(isequal(s, prior) && out(1) == 0);
end
for k = 1:20
    [s, out] = pam3_step(s, 0, 2, cfg); trace(numel(x)+k, :) = out';
end
b = pam3_trace_decode(trace); assert(isequal(a.symbols, b.symbols));
assert(isequal(a.points, b.points));
[s, ~] = pam3_step(s, 0, 3, cfg); assert(isequal(s, pam3_initial_state(cfg)));

% Packer/reader and original host format fixture, including terminal records.
host = load(fullfile(root, 'data', 'host_golden.mat'));
state = zeros(70, 1); bytes = uint8([]);
aa = pam3_decode(host.adc_master, cfg); bb = pam3_decode(host.adc_slave, cfg);
for k = 1:size(aa.trace, 1)
    [state, y] = pam3_packer_step(state, aa.trace(k, :)', bb.trace(k, :)', 0);
    for channel = 0:1
        if y(channel+1)
            bytes = [bytes; uint8(y(3+16*channel:18+16*channel))]; %#ok<AGROW>
        end
    end
end
assert(isequal(bytes(:), host.expected_bytes(:)), 'PAM3:HostBytes', 'Host byte mismatch.');
filename = fullfile(root, 'results', 'core_host_validation.bin');
fid = fopen(filename, 'wb'); assert(fid >= 0); fwrite(fid, bytes, 'uint8'); fclose(fid);
records = pam3_read_host(filename);
for channel = 0:1
    observed = [];
    for k = 1:numel(records)
        if records(k).channel == channel
            observed = [observed; records(k).symbols]; %#ok<AGROW>
        end
    end
    if channel == 0
        expected = aa.symbols;
    else
        expected = bb.symbols;
    end
    assert(isequal(observed, expected));
end
runtime_product = 'MATLAB'; matlab_executed = true; report_name = 'matlab_validation.mat';
if exist('OCTAVE_VERSION', 'builtin')
    runtime_product = 'GNU Octave'; matlab_executed = false; report_name = 'octave_validation.mat';
end
report = struct('passed', true, 'quick', logical(quick), ...
    'captures_checked', checked, 'samples_checked', samples, ...
    'symbols_checked', symbols, 'elapsed_seconds', toc(started), ...
    'runtime', version, 'runtime_product', runtime_product, ...
    'matlab_executed', matlab_executed, 'simulink_executed', false);
save(fullfile(root, 'results', report_name), 'report', '-v7');
fprintf('PASS MATLAB-language: %d captures, %d samples, %d symbols.\n', checked, samples, symbols);
end
