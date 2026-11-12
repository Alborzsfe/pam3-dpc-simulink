function figures = plot_comparison(result)
% Plot only; calculations are performed on the full common measurement window.
cfg = result.config; data = result.input;
colors = [0.15, 0.36, 0.78; 0.03, 0.57, 0.43];
visible = 'off';
if cfg.show_figures
    visible = 'on';
end
figures = {};
for s = 1:2
    scenario = result.rows(2*s-1).scenario;
    f = figure('Name', [scenario ' input comparison'], 'Color', 'w', ...
        'Visible', visible, 'Position', [80, 60, 1100, 850]);
    figures{end+1} = f; %#ok<AGROW>
    first = data.measure_index(1);
    ix = first:(first+2*data.samples_per_cycle-1);
    tm = 1000*(data.t(ix)-data.t(first));
    subplot(4, 1, 1);
    plot(tm, data.analog(ix, s), 'Color', [0.6, 0.65, 0.7]); hold on;
    plot(tm, data.normalized_adc(ix, s), 'k');
    grid on; ylabel('Input');
    legend('Before ADC', 'Same ADC input to both', 'Location', 'northeast');
    title([scenario ': identical input; first two measured cycles']);
    subplot(4, 1, 2);
    stairs(tm, cfg.output_volts_per_level*result.output_levels(ix, 1, s), ...
        'Color', colors(1, :), 'LineWidth', 1.2); hold on;
    stairs(tm, cfg.output_volts_per_level*result.output_levels(ix, 2, s), ...
        'Color', colors(2, :), 'LineWidth', 1.2);
    grid on; ylabel('Assumed V'); ylim(1.3*cfg.output_volts_per_level*[-1, 1]);
    legend('Hysteresis', 'Original PAM3 + hold', 'Location', 'northeast');
    title('Causal output: no time shift or smoothing');
    subplot(4, 1, 3);
    for b = 1:2
        v = cfg.output_volts_per_level*result.output_levels(ix, b, s);
        stairs(tm, v.^2/cfg.resistance_ohm, 'Color', colors(b, :), ...
            'LineWidth', 1.2); hold on;
    end
    grid on; ylabel('Assumed W'); xlabel('Time after measurement start (ms)');
    ylim([-0.1, 1.2]*cfg.output_volts_per_level^2/cfg.resistance_ohm);
    title('Hypothetical resistor power: p = v^2/R');
    subplot(4, 1, 4);
    values = zeros(cfg.max_harmonic, 2);
    for b = 1:2
        m = result.rows(2*s-2+b).metrics;
        values(:, b) = 100*m.harmonic_rms/m.fundamental_rms_v;
    end
    bars = bar(2:cfg.max_harmonic, values(2:end, :));
    for b = 1:2
        set(bars(b), 'FaceColor', colors(b, :));
    end
    grid on; xlabel('Harmonic order'); ylabel('% of fundamental');
    legend('Hysteresis', 'Original PAM3 + hold', 'Location', 'northeast');
    title(sprintf('THD(2..%d): H %.2f%% | PAM3 %.2f%%; measurement = %d cycles', ...
        cfg.max_harmonic, result.rows(2*s-1).metrics.thd_percent, ...
        result.rows(2*s).metrics.thd_percent, cfg.measure_cycles));
    if cfg.save_results
        print(f, fullfile(cfg.output_dir, [lower(scenario) '_comparison.png']), ...
            '-dpng', '-r150');
    end
end
end
