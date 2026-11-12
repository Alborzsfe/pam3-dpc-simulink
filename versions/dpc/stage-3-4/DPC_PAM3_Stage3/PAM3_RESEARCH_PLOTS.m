function PAM3_RESEARCH_PLOTS(r,cfg,folder)
names={'Professor original band','Professor matched band','Model-assisted'};
f=figure('Visible','off','Color','w','Position',[100 100 1300 1100]);tiledlayout(5,1);
for panel=1:5
    nexttile;hold on;
    for k=1:3
        s=r{k}.raw;
        if panel==1,y=s.P;v=y.signals.values;
        elseif panel==2,y=s.Q;v=y.signals.values;
        elseif panel==3,y=s.I;v=reshape(y.signals.values,numel(y.time),[]);v=v(:,1);
        elseif panel==4,y=s.P;v=y.signals.values-PAM3_SAMPLE(s.Pref,y.time);
        else,y=s.Q;v=y.signals.values-PAM3_SAMPLE(s.Qref,y.time);end
        plot(y.time,v);
    end
    if panel<=2
        if panel==1,ref=r{3}.raw.Pref;else,ref=r{3}.raw.Qref;end
        plot(ref.time,ref.signals.values,'k--');
    end
    labels={'Physical P (W)','Physical Q (var)','Phase A current (A)','P - Pref (W)','Q - Qref (var)'};
    ylabel(labels{panel});grid on;
    if panel==1,legend([names {'Reference'}],'Location','best');end
end
xlabel('Time (s)');saveas(f,fullfile(folder,'power_current_errors.png'));close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1300 1100]);tiledlayout(3,2);
for k=1:3
    for axis=1:2
        nexttile;hold on;s=r{k}.raw;
        if axis==1,y=s.sp;else,y=s.sq;end
        stairs(y.time,y.signals.values);ylim([-1.2 1.2]);grid on;
        title([names{k} ' - ' char('P'+(axis-1))]);ylabel('Decision');
    end
end
saveas(f,fullfile(folder,'hysteresis_decisions.png'));close(f);
% Display WIDTHS and effective RAW-ERROR boundaries separately.
f=figure('Visible','off','Color','w','Position',[100 100 1300 1100]);tiledlayout(3,2);
for k=1:3
    s=r{k}.raw.Diagnostics;t=s.time;v=reshape(s.signals.values,numel(t),[]);
    for axis=1:2
        nexttile;h=v(:,5+2*(axis-1));l=v(:,6+2*(axis-1));center=v(:,8+axis);
        plot(t,[center+h center+l center-l center-h]);grid on;
        ylabel('Raw error boundary (pu)');title([names{k} ' - ' char('P'+(axis-1))]);
    end
end
saveas(f,fullfile(folder,'effective_decision_boundaries.png'));close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1300 1100]);tiledlayout(3,2);
for k=1:3
    s=r{k}.raw.Diagnostics;t=s.time;v=reshape(s.signals.values,numel(t),[]);
    pb=max(abs(PAM3_SAMPLE(r{k}.raw.Pref,t)),1);
    qr=abs(PAM3_SAMPLE(r{k}.raw.Qref,t));qb=pb;qb(qr>=1)=qr(qr>=1);
    for axis=1:2
        nexttile;h=v(:,5+2*(axis-1));l=v(:,6+2*(axis-1));center=v(:,8+axis);
        if axis==1,base=pb;unit='W';else,base=qb;unit='var';end
        plot(t,[center+h center+l center-l center-h].*base);grid on;
        ylabel(['Raw error boundary (' unit ')']);title(names{k});
    end
end
saveas(f,fullfile(folder,'effective_boundaries_power_units.png'));close(f);
f=figure('Visible','off','Color','w','Position',[100 100 1300 1100]);tiledlayout(3,1);
s=r{3}.raw.Diagnostics;t=s.time;v=reshape(s.signals.values,numel(t),[]);
nexttile;plot(t,v(:,5:8));ylabel('Band half-width (pu)');grid on;
nexttile;plot(t,v(:,11:12));ylabel('Observer weights');grid on;
nexttile;plot(t,v(:,13:14));ylabel('Innovation indicators');grid on;
xlabel('Time (s)');saveas(f,fullfile(folder,'adaptation_audit.png'));close(f);
% Three phase current over a common final two grid cycles, plus physical V.
f=figure('Visible','off','Color','w','Position',[100 100 1300 1100]);tiledlayout(4,1);
for k=1:3
    nexttile;s=r{k}.raw.I;v=reshape(s.signals.values,numel(s.time),[]);
    plot(s.time,v);xlim([cfg.window(2)-2/cfg.fundamentalHz cfg.window(2)]);
    ylabel('Iabc (A)');title(names{k});grid on;
end
nexttile;s=r{3}.raw.V;plot(s.time,reshape(s.signals.values,numel(s.time),[]));
xlim([cfg.window(2)-2/cfg.fundamentalHz cfg.window(2)]);ylabel('PCC Vabc (V)');grid on;
saveas(f,fullfile(folder,'current_and_PCC_voltage.png'));close(f);
end
