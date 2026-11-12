function results = run_quality_study(cfg, parameter_note)
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'matlab'), fullfile(root, 'patent_core'));
if nargin < 1, cfg = quality_config(); end
if nargin < 2, parameter_note = 'phase voltage explicitly supplied in quality_config'; end
quality_validate_config(cfg);
methods = {'conventional', 'proposed'};
results = cell(numel(cfg.control_frequencies_hz), 2);
for frequency = 1:numel(cfg.control_frequencies_hz)
    fs = cfg.control_frequencies_hz(frequency);
    for method = 1:2
        [model, info] = build_quality_model(methods{method}, fs, cfg);
        folder = fullfile(root, 'results', sprintf('%gk_%s', fs/1000, methods{method}));
        if ~exist(folder, 'dir'), mkdir(folder); end
        fprintf('\nRunning CLOSED-LOOP %s at control Fs=%g kHz; plant step=%g us.\n', ...
            methods{method}, fs/1000, cfg.plant_step*1e6);
        timer = tic;
        out = sim(model, 'ReturnWorkspaceOutputs', 'on', 'SimulationMode', 'normal');
        names = {'iabc', 'vabc', 'vdc', 'p', 'pref', 'q', 'qref', 'gates'};
        raw = struct();
        for k = 1:numel(names)
            raw.(names{k}) = out.get(['quality_log_' names{k}]);
        end
        elapsed_s = toc(timer);
        info.simulink_executed = true;
        info.closed_loop_executed = true;
        save(fullfile(folder, 'native_simulink_logs.mat'), 'raw', 'cfg', 'info', 'elapsed_s', '-v7');
        result = quality_analyze_run(raw, cfg, info, parameter_note);
        result.elapsed_s = elapsed_s;
        quality_export_run(result, folder);
        results{frequency, method} = result;
        fprintf('Completed: THD_a(2..%d)=%.4g%%; mean P=%.4g W; average gate rate=%.4g kHz.\n', ...
            cfg.max_harmonic, result.fft{1}.thd_percent, result.metrics.p.mean, ...
            result.metrics.mean_equivalent_switching_hz/1000);
        if ~result.metrics.stationary_window
            fprintf('NOTE: FFT window still drifts; extend stop_time and move fft_start later before interpreting steady-state quality.\n');
        end
    end
    quality_plot_pair(results{frequency,1}, results{frequency,2}, ...
        fullfile(root, 'SEND_TO_PROFESSOR'));
end
save(fullfile(root, 'results', 'all_closed_loop_results.mat'), 'results', 'cfg', '-v7');
quality_export_summary(results, fullfile(root, 'SEND_TO_PROFESSOR'));
fprintf('\nDONE: %s\n', fullfile(root, 'SEND_TO_PROFESSOR'));
end
