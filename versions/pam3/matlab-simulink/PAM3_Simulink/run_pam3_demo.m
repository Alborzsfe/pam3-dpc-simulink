function result = run_pam3_demo(cfg, rebuild)
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'));
addpath(fullfile(root, 'models'));
if nargin < 1
    cfg = pam3_config();
end
if nargin < 2
    rebuild = true;
end
pam3_validate_config(cfg);
demo = load(fullfile(root, 'data', 'demo_capture.mat'));
pam3_assign_inputs(demo.adc_master, demo.adc_slave, cfg);
if rebuild
    build_pam3_models();
end
load_system(fullfile(root, 'models', 'pam3_patent_demo.slx'));
simulation = sim('pam3_patent_demo', 'ReturnWorkspaceOutputs', 'on');
master = get_trace(simulation.get('trace_master'), 18);
slave = get_trace(simulation.get('trace_slave'), 18);
host = get_trace(simulation.get('trace_host'), 34);
actual_a = pam3_trace_decode(master); actual_b = pam3_trace_decode(slave);
expected_a = pam3_decode(demo.adc_master, cfg);
expected_b = pam3_decode(demo.adc_slave, cfg);
assert(isequal(master, expected_a.trace), 'PAM3:SimulinkMaster', 'Master trace mismatch.');
assert(isequal(slave, expected_b.trace), 'PAM3:SimulinkSlave', 'Slave trace mismatch.');
bytes = uint8([]); pack_state = zeros(70, 1);
for k = 1:size(host, 1)
    [pack_state, packet] = pam3_packer_step(pack_state, master(k, :)', slave(k, :)', 0);
    assert(isequal(host(k, :)', packet), 'PAM3:SimulinkPacker', 'Packer trace mismatch.');
    for channel = 0:1
        if packet(channel+1)
            bytes = [bytes; uint8(packet(3+16*channel:18+16*channel))]; %#ok<AGROW>
        end
    end
end
fid = fopen(fullfile(root, 'results', 'simulink_host_records.bin'), 'wb');
assert(fid >= 0); fwrite(fid, bytes, 'uint8'); fclose(fid);
result = struct('cfg', cfg, 'master', actual_a, 'slave', actual_b, ...
    'host_trace', host, 'host_bytes', bytes, 'simulink_executed', true, ...
    'simulation_time', master_time(simulation.get('trace_master')));
save(fullfile(root, 'results', 'simulink_demo_result.mat'), 'result', '-v7');
write_symbols(fullfile(root, 'results', 'decoded_symbols.csv'), actual_a, actual_b);
fprintf('PASS Simulink: %d master and %d slave symbols.\n', ...
    numel(actual_a.symbols), numel(actual_b.symbols));
plot_pam3_result(result, demo, root);
open_system('pam3_patent_demo');
end

function trace = get_trace(saved, width)
trace = reshape(saved.signals.values, [], width);
end

function t = master_time(saved)
t = saved.time;
end

function write_symbols(filename, a, b)
fid = fopen(filename, 'w'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'channel,ordinal,sample_index,symbol\n');
for channel = 0:1
    if channel == 0
        d = a;
    else
        d = b;
    end
    for k = 1:numel(d.symbols)
        fprintf(fid, '%d,%d,%d,%d\n', channel, k-1, d.points(k), d.symbols(k));
    end
end
end
