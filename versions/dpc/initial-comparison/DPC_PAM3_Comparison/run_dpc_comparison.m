function result = run_dpc_comparison(capture, cfg)
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'), fullfile(root, 'patent_core'));
if nargin < 2, cfg = dpc_config(); end
result = dpc_compare_core(capture, cfg);
folder = fullfile(root, 'results', capture.kind);
if ~exist(folder, 'dir'), mkdir(folder); end
if cfg.run_replay_simulink
    dpc_prepare_replay_inputs(capture, cfg);
    build_dpc_replay_model(cfg);
    simout = sim('dpc_same_input_comparison', 'ReturnWorkspaceOutputs', 'on');
    n = numel(capture.time);
    for channel = 1:2
        label = cfg.channels{channel}; c = result.channels{channel};
        binary_log = simout.get(['dpc_binary_' label]);
        ternary_log = simout.get(['dpc_ternary_' label]);
        patent_log = simout.get(['dpc_patent_' label]);
        b = reshape(binary_log.signals.values, [], 1);
        z = reshape(ternary_log.signals.values, [], 1);
        trace = reshape(patent_log.signals.values, [], 18);
        assert(numel(b) == n+20 && numel(z) == n+20 && size(trace, 1) == n+20, ...
            'DPC:ReplayLength', 'Unexpected replay time grid.');
        assert(isequal(double(b(1:n)), c.binary), 'DPC:BinaryReplay', 'Relay replay differs from core.');
        assert(isequal(double(z(1:n)), c.ternary), 'DPC:TernaryReplay', 'Ternary replay differs from core.');
        assert(isequal(double(trace), c.patent.trace), 'DPC:PatentReplay', 'Patent replay trace differs from core.');
    end
    result.simulink_replay_executed = true;
    fprintf('PASS actual Simulink same-input replay: 2 channels, %d samples each.\n', n);
    open_system('dpc_same_input_comparison');
end
save(fullfile(folder, 'comparison_result.mat'), 'result', '-v7');
dpc_write_reports(result, folder);
dpc_plot_comparison(result, folder);
end
