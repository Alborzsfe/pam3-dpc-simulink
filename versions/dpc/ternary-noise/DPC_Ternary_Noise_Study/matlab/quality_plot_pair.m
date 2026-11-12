function quality_plot_pair(conventional, proposed, folder)
assert(conventional.closed_loop_executed && proposed.closed_loop_executed, ...
    'QUALITY:Provenance', 'Professor figures require actual closed-loop simulation results.');
if ~exist(folder, 'dir'), mkdir(folder); end
pair = {conventional, proposed}; labels = {'Conventional DPC / hysteresis', 'Proposed / true ternary + nine-state table'};
cfg = conventional.cfg; fs = conventional.info.control_hz;
last = cfg.fft_start+cfg.fft_cycles/cfg.line_frequency;
first = last-cfg.plot_cycles/cfg.line_frequency;
limits_i = [Inf, -Inf]; limits_p = [Inf, -Inf];
for k = 1:2
    r = pair{k}; ix = r.time >= first & r.time <= last;
    limits_i = [min(limits_i(1), min(r.signals.iabc(ix,1))), ...
        max(limits_i(2), max(r.signals.iabc(ix,1)))];
    limits_p = [min([limits_p(1); r.signals.p(ix); r.signals.pref(ix)]), ...
        max([limits_p(2); r.signals.p(ix); r.signals.pref(ix)])];
end
f = figure('Color', 'w', 'Position', [80,80,1450,800], 'Visible', cfg.plot_visible);
layout = tiledlayout(f, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:2
    r = pair{k}; ix = r.time >= first & r.time <= last;
    ax = nexttile(layout, 2*k-1);
    plot(ax, r.time(ix), r.signals.iabc(ix,1), 'Color', [0.05,0.35,0.65], 'LineWidth', 1);
    grid(ax, 'on'); xlim(ax, [first,last]); ylim(ax, padded(limits_i));
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Phase-a current (A)');
    title(ax, sprintf('%s | THD_{2..%d} = %.3f%%', labels{k}, cfg.max_harmonic, r.fft{1}.thd_percent));
    ax = nexttile(layout, 2*k);
    plot(ax, r.time(ix), r.signals.p(ix), 'Color', [0.05,0.35,0.65], 'LineWidth', 1);
    hold(ax, 'on'); plot(ax, r.time(ix), r.signals.pref(ix), '--', 'Color', [0.8,0.25,0.1]);
    grid(ax, 'on'); xlim(ax, [first,last]); ylim(ax, padded(limits_p));
    xlabel(ax, 'Time (s)'); ylabel(ax, 'Active power (W)');
    title(ax, sprintf('P ripple: peak-to-peak %.3g W; RMS %.3g W', ...
        r.metrics.p.peak_to_peak, r.metrics.p.ripple_rms));
    legend(ax, {'True P','Reference P'}, 'Location', 'best');
end
title(layout, sprintf('Control sampling Fs = %g kHz | same plant step %g us', fs/1000, cfg.plant_step*1e6));
if isfield(conventional.info,'study_case')
    title(layout,sprintf('%s | seed %u | control Fs %g kHz', ...
        conventional.info.study_case.label,conventional.info.noise_seed,fs/1000),'Interpreter','none');
end
subtitle(layout, window_note(pair));
base = fullfile(folder, sprintf('%gk_current_and_active_power', fs/1000));
exportgraphics(f, [base '.png'], 'Resolution', 180); savefig(f, [base '.fig']);
g = figure('Color', 'w', 'Position', [100,100,1400,800], 'Visible', cfg.plot_visible);
layout = tiledlayout(g, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
upper = 1;
for k = 1:2
    finite_values = pair{k}.fft{1}.harmonic_percent(2:end);
    finite_values = finite_values(isfinite(finite_values));
    if ~isempty(finite_values), upper = max(upper, max(finite_values)*1.15); end
end
for k = 1:2
    r = pair{k}; ax = nexttile(layout);
    bar(ax, r.fft{1}.orders(2:end), r.fft{1}.harmonic_percent(2:end), ...
        'FaceColor', [0.05,0.35,0.65]);
    grid(ax, 'on'); xlim(ax, [1.5,cfg.max_harmonic+0.5]); ylim(ax, [0,upper]);
    xlabel(ax, sprintf('Harmonic order (fundamental = %g Hz)',cfg.line_frequency));
    ylabel(ax, '% of fundamental RMS');
    title(ax, sprintf('%s | THD_{2..%d} = %.3f%% | I_1 = %.4g A RMS', ...
        labels{k}, cfg.max_harmonic, r.fft{1}.thd_percent, r.fft{1}.fundamental_rms));
end
title(layout, sprintf('Phase-a harmonic FFT | control Fs = %g kHz', fs/1000));
subtitle(layout, window_note(pair));
base = fullfile(folder, sprintf('%gk_current_FFT', fs/1000));
exportgraphics(g, [base '.png'], 'Resolution', 180); savefig(g, [base '.fig']);
if strcmp(cfg.plot_visible, 'off'), close(f); close(g); end
end

function limits = padded(limits)
margin = max(0.05*(limits(2)-limits(1)), 1e-6); limits = limits+[-margin,margin];
end

function note = window_note(pair)
cfg = pair{1}.cfg;
status = 'steady-window drift check passed';
if ~pair{1}.metrics.stationary_window || ~pair{2}.metrics.stationary_window
    status = 'TRANSIENT WINDOW: extend simulation before steady-state interpretation';
end
note = sprintf(['FFT/ripple: %.3f..%.3f s, %d cycles, harmonics 2..%d only | ' ...
    'measured mean f_{sw}: %.3g / %.3g kHz | %s'], ...
    cfg.fft_start, cfg.fft_start+cfg.fft_cycles/cfg.line_frequency, cfg.fft_cycles, ...
    cfg.max_harmonic, pair{1}.metrics.mean_equivalent_switching_hz/1000, ...
    pair{2}.metrics.mean_equivalent_switching_hz/1000, status);
end
