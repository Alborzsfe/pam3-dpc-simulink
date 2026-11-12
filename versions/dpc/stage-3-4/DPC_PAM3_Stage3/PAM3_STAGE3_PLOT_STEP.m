function PAM3_STAGE3_PLOT_STEP(r,cfg,folder)
% Draw actual Q/P and common references over exactly the same time axis.
n=round(diff(cfg.stepPlotWindow)/cfg.Ts);
t=cfg.stepPlotWindow(1)+(0:n-1)'*cfg.Ts;
raw1=r{1}.raw;raw2=r{2}.raw;
q1=PAM3_SAMPLE(raw1.Q,t);q2=PAM3_SAMPLE(raw2.Q,t);
p1=PAM3_SAMPLE(raw1.P,t);p2=PAM3_SAMPLE(raw2.P,t);
qr=PAM3_SAMPLE(raw1.Qref,t);pr=PAM3_SAMPLE(raw1.Pref,t);
trace=table(t,qr,q1,q2,pr,p1,p2,'VariableNames', ...
    {'Time_s','Qref_var','Q_Baseline_var','Q_Proposed_var', ...
    'Pref_W','P_Baseline_W','P_Proposed_W'});
writetable(trace,fullfile(folder,'step_traces.csv'));
fig=figure('Visible','off','Color','w','Position',[100 100 1050 890]);
cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
layout=tiledlayout(fig,3,1,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout);
traceplot(ax,t,q1,q2,qr,cfg.stepTime,cfg.stepPlotWindow);
ylabel(ax,'Q (var)');
title(ax,sprintf('Q step 0 to %+g var at %.2f s | L = %g mH', ...
    cfg.Qafter,cfg.stepTime,1000*cfg.modelL));
legend(ax,{'DPC with frozen tuned band','Proposed','Reference'},'Location','best');
ax=nexttile(layout);
traceplot(ax,t,q1,q2,qr,cfg.stepTime,[cfg.stepTime-.01 cfg.stepTime+.05]);
ylabel(ax,'Q (var)');title(ax,'Detail around the step');
ax=nexttile(layout);
traceplot(ax,t,p1,p2,pr,cfg.stepTime,cfg.stepPlotWindow);
ylabel(ax,'P (W)');xlabel(ax,'Time (s)');title(ax,'Active power with P reference held at 400 W');
print(fig,fullfile(folder,'q_step_comparison.png'),'-dpng','-r150');
end

function traceplot(ax,t,x,y,ref,stepTime,lim)
plot(ax,t,x,'Color',[.20 .35 .63],'LineWidth',1.05);hold(ax,'on');
plot(ax,t,y,'Color',[.77 .30 .14],'LineWidth',1.05);
stairs(ax,t,ref,'k--','LineWidth',1.15);
xline(ax,stepTime,':','Color',[.40 .40 .40],'HandleVisibility','off');
xlim(ax,lim);grid(ax,'on');box(ax,'on');
end
