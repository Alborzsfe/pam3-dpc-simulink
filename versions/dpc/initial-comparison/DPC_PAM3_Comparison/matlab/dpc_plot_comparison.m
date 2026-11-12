function dpc_plot_comparison(result, folder)
% Export actual run figures. Educational and converter results stay labelled.
cfg = result.cfg; t = result.capture.time * 1000;
provenance = strrep(result.kind, '_', ' ');
for channel = 1:2
    c = result.channels{channel}; label = cfg.channels{channel};
    f = figure('Name', ['Same input - channel ' label], 'Color', 'w', ...
        'Visible', cfg.plot_visible, 'Position', [80, 70, 1300, 850]);
    ax = cell(4, 1);
    ax{1} = subplot(4, 1, 1);
    plot(t, c.error, 'Color', [.12 .25 .45]); hold on;
    yline(cfg.relay_on(channel), '--', '+H'); yline(cfg.relay_off(channel), '--', '-H');
    grid on; ylabel(['e_' label ' (model units)']);
    title(['Same input comparison | ' label ' | ' provenance], 'Interpreter', 'none');
    ax{2} = subplot(4, 1, 2);
    stairs(t, c.binary, 'Color', [.7 .32 .1], 'LineWidth', 1); hold on;
    if isfield(result.capture, 'original_binary')
        stairs(t, result.capture.original_binary(:, channel), '--', 'Color', [.35 .35 .35]);
        legend('Sampled binary replay', 'Observed converter relay', 'Location', 'best');
    else
        legend('Sampled binary relay (0/1)', 'Location', 'best');
    end
    grid on; ylabel('Binary'); ylim([-.25, 1.25]);
    ax{3} = subplot(4, 1, 3);
    stairs(t, c.ternary, 'Color', [.05 .48 .38], 'LineWidth', 1);
    grid on; ylabel('Control ternary'); ylim([-1.25, 1.25]); yticks([-1, 0, 1]);
    ax{4} = subplot(4, 1, 4);
    stairs(t, c.raw, 'Color', [.49 .28 .67]); hold on;
    filtered = c.filtered_causal; filtered(~c.filtered_valid) = NaN;
    stairs(t, filtered, 'Color', [.13 .45 .72]);
    grid on; ylabel('Mapped patent'); xlabel('Time (ms)');
    ylim([-1.25, 1.25]); yticks([-1, 0, 1]);
    legend('Raw classifier', 'Causal spike filter (2 ticks later)', 'Location', 'best');
    linkaxes([ax{:}], 'x');
    saveas(f, fullfile(folder, ['01_same_input_' label '.png']));
    savefig(f, fullfile(folder, ['01_same_input_' label '.fig']));
end
f = figure('Name', 'Decision metrics', 'Color', 'w', 'Visible', cfg.plot_visible, ...
    'Position', [100, 90, 1300, 600]);
names = {'Binary', 'Control ternary', 'Patent raw', 'Patent filter'};
for channel = 1:2
    rows = result.channels{channel}.metrics;
    changes = cellfun(@(r) r.decision_changes, rows);
    neutral = cellfun(@(r) 100*r.neutral_fraction, rows);
    subplot(2, 2, channel); bar(changes, 'FaceColor', [.15 .4 .58]); grid on;
    xticks(1:4); xticklabels(names); ylabel('Decision changes');
    title(['Channel ' cfg.channels{channel} ' | ' provenance], 'Interpreter', 'none');
    subplot(2, 2, channel+2); bar(neutral, 'FaceColor', [.1 .5 .38]); grid on;
    xticks(1:4); xticklabels(names); ylabel('Neutral samples (%)'); ylim([0,100]);
end
saveas(f, fullfile(folder, '02_decision_metrics.png'));
savefig(f, fullfile(folder, '02_decision_metrics.fig'));
f = figure('Name', 'Patent timing', 'Color', 'w', 'Visible', cfg.plot_visible, ...
    'Position', [120, 100, 1250, 650]);
for channel = 1:2
    c = result.channels{channel};
    subplot(2, 1, channel);
    stairs(t, c.raw, 'Color', [.49 .28 .67]); hold on;
    stem(c.symbol_emission_time*1000, c.patent.symbols, '.', 'Color', [.05 .38 .68]);
    grid on; ylim([-1.3, 1.3]); ylabel(['Channel ' cfg.channels{channel}]);
    title(['Patent symbol EMISSION time | ' provenance ' | latency 20 Ts'], 'Interpreter', 'none');
    legend('Sample-rate raw level', 'Sparse output symbols at availability time', 'Location', 'best');
end
xlabel('Time (ms)');
saveas(f, fullfile(folder, '03_patent_timing.png'));
savefig(f, fullfile(folder, '03_patent_timing.fig'));
end
