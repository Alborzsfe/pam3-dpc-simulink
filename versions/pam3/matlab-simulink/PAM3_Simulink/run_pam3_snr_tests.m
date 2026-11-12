function rows = run_pam3_snr_tests(use_simulink)
% New experiments in the selected runtime; original Python SER is not reused.
if nargin < 1
    use_simulink = true;
end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab')); addpath(fullfile(root, 'models'));
if use_simulink
    build_pam3_models();
end
rows = struct('snr_db', {}, 'seed', {}, 'channel', {}, 'method', {}, ...
    'evaluated', {}, 'errors', {}, 'missing', {}, 'duplicates', {}, 'wrong_value', {}, 'ser', {});
for snr = [10, 18, 30]
    for rep = 1:3
        options = struct('symbols', 512, 'snr_db', snr, 'seed', 11405248+rep*1009+snr*101);
        input = generate_pam3_input(options);
        for method = 1:3
            cfg = pam3_config();
            names = {'fixed_dc_off', 'q8_adaptive_dc_off', 'literal_dc'};
            cfg.adaptive_mode = double(method == 2);
            cfg.dc_enabled = method == 3;
            if use_simulink
                pam3_assign_inputs(input.adc_master, input.adc_slave, cfg);
                simulation = sim('pam3_patent_demo', 'ReturnWorkspaceOutputs', 'on');
                a = simulation.get('trace_master'); b = simulation.get('trace_slave');
                decoded = {pam3_trace_decode(reshape(a.signals.values, [], 18)), ...
                           pam3_trace_decode(reshape(b.signals.values, [], 18))};
            else
                decoded = {pam3_decode(input.adc_master, cfg), pam3_decode(input.adc_slave, cfg)};
            end
            transmitters = {input.tx_master, input.tx_slave};
            boundaries = {input.boundaries_master, input.boundaries_slave};
            for channel = 1:2
                metrics = pam3_evaluate(transmitters{channel}, boundaries{channel}, decoded{channel});
                rows(end+1) = struct('snr_db', snr, 'seed', options.seed, 'channel', channel-1, ...
                    'method', names{method}, 'evaluated', metrics.evaluated, ...
                    'errors', metrics.errors, 'missing', metrics.missing, ...
                    'duplicates', metrics.duplicated_intervals, 'wrong_value', metrics.wrong_value_single, ...
                    'ser', metrics.ser_total); %#ok<AGROW>
            end
        end
        fprintf('Completed SNR %d dB / seed %d\n', snr, rep);
    end
end
filename = fullfile(root, 'results', 'new_snr_results.csv');
fid = fopen(filename, 'w'); assert(fid >= 0);
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, 'snr_db,seed,channel,method,evaluated,errors,missing,duplicates,wrong_value,ser\n');
for k = 1:numel(rows)
    r = rows(k);
    fprintf(fid, '%d,%d,%d,%s,%d,%d,%d,%d,%d,%.12g\n', r.snr_db, r.seed, r.channel, ...
        r.method, r.evaluated, r.errors, r.missing, r.duplicates, r.wrong_value, r.ser);
end
save(fullfile(root, 'results', 'new_snr_results.mat'), 'rows', 'use_simulink', '-v7');
fprintf('Saved %d method/channel trials; Simulink execution = %d.\n', numel(rows), use_simulink);
end
