function dpc3_noise_plot_feedback(conventional,proposed,folder)
pair = {conventional,proposed};cfg = conventional.cfg;
assert(all(cellfun(@(r) r.simulink_executed && r.closed_loop_executed,pair)));
last = cfg.fft_start+cfg.fft_cycles/cfg.line_frequency;
first = last-cfg.plot_cycles/cfg.line_frequency;
f = figure('Color','w','Position',[90,90,1450,900],'Visible',cfg.plot_visible);
layout = tiledlayout(f,3,2,'TileSpacing','compact','Padding','compact');
names = {'Conventional','Ternary'};
for k = 1:2
    r = pair{k};ix = r.time >= first & r.time <= last;
    ax = nexttile(layout,k);
    plot(ax,r.time(ix),r.signals.vabc(ix,1),r.time(ix),r.signals.v_feedback(ix,1));
    grid(ax,'on');ylabel(ax,'Phase-a voltage (V)');xlim(ax,[first,last]);
    legend(ax,{'Physical voltage','Sensor voltage'},'Location','best');title(ax,names{k});
    ax = nexttile(layout,2+k);
    plot(ax,r.time(ix),r.signals.p(ix),r.time(ix),r.signals.p_feedback(ix));
    hold(ax,'on');plot(ax,r.time(ix),r.signals.pref(ix),'k--');
    grid(ax,'on');ylabel(ax,'Active power (W)');xlim(ax,[first,last]);
    legend(ax,{'True P','Controller P feedback','P reference'},'Location','best');
    ax = nexttile(layout,4+k);
    plot(ax,r.time,r.signals.vdc);hold(ax,'on');yline(ax,cfg.dc_reference,'k--');
    xline(ax,cfg.disturbance_start,':r','Disturbance on');grid(ax,'on');
    xlabel(ax,'Time (s)');ylabel(ax,'DC voltage (V)');
end
title(layout,sprintf('%s | seed %u | control Fs %g kHz',conventional.info.study_case.label, ...
    conventional.info.noise_seed,conventional.info.control_hz/1000),'Interpreter','none');
base = fullfile(folder,sprintf('%gk_feedback_and_dc',conventional.info.control_hz/1000));
exportgraphics(f,[base '.png'],'Resolution',160);savefig(f,[base '.fig']);
if strcmp(cfg.plot_visible,'off'),close(f);end
end
