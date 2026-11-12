function m=PAM3_FULL_FEATURE_STATS(raw,cfg)
% Summary over the same measurement window as THD, ripple and switching.
n=round(diff(cfg.window)/cfg.Ts);
t=cfg.window(1)+((0:n-1)'+.5)*cfg.Ts;
d=PAM3_SAMPLE(raw.Diagnostics,t);
assert(size(d,2)==14 || size(d,2)==42,'PAM3Full:Diagnostics','Unexpected diagnostics width.');
labels={'P_EnterMinPu','P_EnterMeanPu','P_EnterMaxPu','P_ExitMeanPu', ...
    'Q_EnterMinPu','Q_EnterMeanPu','Q_EnterMaxPu','Q_ExitMeanPu', ...
    'P_IndicatorMeanPu','Q_IndicatorMeanPu','P_GateRejectedTicks','Q_GateRejectedTicks', ...
    'P_PersistenceWaitTicks','Q_PersistenceWaitTicks','P_AcceptedChanges','Q_AcceptedChanges', ...
    'P_MaxConfirmationCount','Q_MaxConfirmationCount','P_BypassTickFraction','Q_BypassTickFraction'};
for k=1:numel(labels),m.(labels{k})=NaN;end
m.P_EnterMinPu=min(d(:,5));m.P_EnterMeanPu=mean(d(:,5));m.P_EnterMaxPu=max(d(:,5));
m.P_ExitMeanPu=mean(d(:,6));
m.Q_EnterMinPu=min(d(:,7));m.Q_EnterMeanPu=mean(d(:,7));m.Q_EnterMaxPu=max(d(:,7));
m.Q_ExitMeanPu=mean(d(:,8));
if size(d,2)==42
    m.P_IndicatorMeanPu=mean(d(:,15));m.Q_IndicatorMeanPu=mean(d(:,29));
    m.P_GateRejectedTicks=sum(d(:,21));m.Q_GateRejectedTicks=sum(d(:,35));
    m.P_PersistenceWaitTicks=sum(d(:,22));m.Q_PersistenceWaitTicks=sum(d(:,36));
    m.P_AcceptedChanges=sum(d(2:end,23));m.Q_AcceptedChanges=sum(d(2:end,37));
    m.P_MaxConfirmationCount=max(d(:,20));m.Q_MaxConfirmationCount=max(d(:,34));
    m.P_BypassTickFraction=mean(d(:,24)>0);m.Q_BypassTickFraction=mean(d(:,38)>0);
end
end
