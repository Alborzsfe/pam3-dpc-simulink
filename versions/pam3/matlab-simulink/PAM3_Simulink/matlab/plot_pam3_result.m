function plot_pam3_result(result, demo, root)
figure('Name', 'PAM3 patent reconstruction - Simulink result', 'Color', 'white');
channels = {result.master, result.slave};
adcs = {demo.adc_master, demo.adc_slave};
for channel = 1:2
    d = channels{channel}; adc = double(adcs{channel}(:));
    first = min(384, max(0, numel(adc)-1)); last = min(numel(adc)-1, first+240);
    window = first:last; indices = window + 1;
    subplot(3, 2, channel);
    plot(window, adc(indices), 'Color', [0.15, 0.35, 0.8]);
    hold on; plot(window, d.corrected(indices), '--', 'Color', [0.8, 0.4, 0.1]);
    ylabel('ADC code'); grid on;
    title(sprintf('Channel %d: ADC / corrected', channel-1));
    subplot(3, 2, channel+2);
    stairs(window, d.raw_levels(indices), 'Color', [0.65, 0.65, 0.65]);
    hold on; stairs(window, d.levels(indices), 'Color', [0.0, 0.5, 0.4]);
    ylabel('PAM3 level'); ylim([-1.4, 1.4]); grid on;
    subplot(3, 2, channel+4);
    keep = d.points >= first & d.points <= last;
    stem(d.points(keep), d.symbols(keep), 'filled');
    ylabel('Output symbol'); xlabel('Zero-based ADC sample index');
    ylim([-1.4, 1.4]); xlim([first, max(first+1, last)]); grid on;
end
saveas(gcf, fullfile(root, 'results', 'simulink_waveform.png'));
end
