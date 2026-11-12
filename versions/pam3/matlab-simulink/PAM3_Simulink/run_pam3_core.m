function result = run_pam3_core(cfg)
% Execute the actual MATLAB-language core without the Simulink solver.
% Useful for reference checks and in GNU Octave; never labelled a Simulink run.
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'));
if nargin < 1
    cfg = pam3_config();
end
demo = load(fullfile(root, 'data', 'demo_capture.mat'));
a = pam3_decode(demo.adc_master, cfg); b = pam3_decode(demo.adc_slave, cfg);
host = zeros(size(a.trace, 1), 34); state = zeros(70, 1);
for k = 1:size(host, 1)
    [state, y] = pam3_packer_step(state, a.trace(k, :)', b.trace(k, :)', 0);
    host(k, :) = y';
end
result = struct('cfg', cfg, 'master', a, 'slave', b, 'host_trace', host, ...
    'runtime_version', version, 'runtime_product', 'MATLAB', 'simulink_executed', false);
if exist('OCTAVE_VERSION', 'builtin')
    result.runtime_product = 'GNU Octave';
end
save(fullfile(root, 'results', 'core_demo_result.mat'), 'result', '-v7');
fid = fopen(fullfile(root, 'results', 'core_host_records.bin'), 'wb'); assert(fid >= 0);
for k = 1:size(host, 1)
    for channel = 0:1
        if host(k, channel+1)
            fwrite(fid, uint8(host(k, 3+16*channel:18+16*channel)), 'uint8');
        end
    end
end
fclose(fid);
records = pam3_read_host(fullfile(root, 'results', 'core_host_records.bin'));
assert(~isempty(records));
fid = fopen(fullfile(root, 'results', 'core_decoded_symbols.csv'), 'w'); assert(fid >= 0);
fprintf(fid, 'channel,ordinal,sample_index,symbol\n');
decoded = {a, b};
for channel = 1:2
    d = decoded{channel};
    for k = 1:numel(d.symbols)
        fprintf(fid, '%d,%d,%d,%d\n', channel-1, k-1, d.points(k), d.symbols(k));
    end
end
fclose(fid);
fprintf('CORE ONLY (%s): %d master, %d slave symbols. Simulink was not executed.\n', ...
    result.runtime_product, numel(a.symbols), numel(b.symbols));
end
