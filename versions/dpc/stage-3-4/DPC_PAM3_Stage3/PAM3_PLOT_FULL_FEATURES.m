function PAM3_PLOT_FULL_FEATURES(run,cfg,folder)
% Plot actual runtime bands, gate evidence and confirmation counters.
d=reshape(run.raw.Diagnostics.signals.values,numel(run.raw.Diagnostics.time),[]);
t=run.raw.Diagnostics.time;
assert(size(d,2)==42,'PAM3Full:Plot','Full-feature trace is unavailable.');
fig=figure('Visible','off','Color','w','Position',[80 80 1150 1100]);
cleanup=onCleanup(@()close(fig)); %#ok<NASGU>
layout=tiledlayout(fig,5,1,'TileSpacing','compact','Padding','compact');
ax=nexttile(layout);plot(ax,t,d(:,5:6));grid(ax,'on');
ylabel(ax,'P band (pu)');legend(ax,{'Entry','Exit'},'Location','best');
title(ax,'Actual decision thresholds, confidence margins and consecutive-sample counts');
ax=nexttile(layout);plot(ax,t,d(:,7:8));grid(ax,'on');ylabel(ax,'Q band (pu)');
ax=nexttile(layout);plot(ax,t,[d(:,17) d(:,31)]);grid(ax,'on');
yline(ax,cfg.fullFeatures.confidenceMarginSigma,'k--');ylabel(ax,'Margin / sigma');
legend(ax,{'P','Q','Gate criterion'},'Location','best');
ax=nexttile(layout);stairs(ax,t,[d(:,20) d(:,34)]);grid(ax,'on');
ylabel(ax,'Confirmation count');ylim(ax,[-.2 cfg.fullFeatures.persistenceSamples+.5]);
ax=nexttile(layout);
stairs(ax,t,[d(:,21) d(:,22) d(:,35) d(:,36)]);grid(ax,'on');
ylabel(ax,'Reject / wait');xlabel(ax,'Time (s)');
legend(ax,{'P gate reject','P persistence wait','Q gate reject','Q persistence wait'},'Location','best');
print(fig,fullfile(folder,'full_feature_diagnostics.png'),'-dpng','-r150');
end
