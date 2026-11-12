function results = RUN_DPC_PAM3_COMPARE()
% Clean grid only; the professor's plant and switching policy are unchanged.
root=fileparts(mfilename('fullpath'));
OPEN_DPC_PAM3();
models={'DPC_PAM3_Baseline','DPC_PAM3_Mapped'};
for k=1:2
    name=models{k};
    if ~bdIsLoaded(name), load_system(fullfile(root,[name '.slx'])); end
    instrument(name);
    simOut=sim(name,'ReturnWorkspaceOutputs','on');
    raw.P=simOut.get('map_P'); raw.Q=simOut.get('map_Q');
    raw.I=simOut.get('map_I'); raw.Vdc=simOut.get('map_Vdc');
    raw.sp=simOut.get('map_sp'); raw.sq=simOut.get('map_sq');
    metrics=analyze(raw);
    results(k).model=name; %#ok<AGROW>
    results(k).metrics=metrics;
    results(k).raw=raw;
    % Logging additions remain unsaved so the delivered plant stays intact.
end
T=struct2table([results.metrics]);
T.Model=string(models(:));
disp(T);
save(fullfile(root,'comparison_results.mat'),'results','T');
writetable(T,fullfile(root,'comparison_metrics.csv'));
f=figure('Name','Original hysteresis vs original PAM3','Color','w');
tiledlayout(3,1);
nexttile; hold on;
for k=1:2, plot(results(k).raw.P.time,results(k).raw.P.signals.values); end
xlabel('Time (s)'); ylabel('P (W)'); legend(models,'Interpreter','none'); grid on;
nexttile; hold on;
for k=1:2, plot(results(k).raw.Q.time,results(k).raw.Q.signals.values); end
xlabel('Time (s)'); ylabel('Q (var)'); grid on;
nexttile; hold on;
for k=1:2
    v=results(k).raw.I.signals.values;
    plot(results(k).raw.I.time,v(:,1));
end
xlim([0.30 0.36]); xlabel('Time (s)'); ylabel('Phase A current (A)'); grid on;
saveas(f,fullfile(root,'comparison_plot.png'));
end

function instrument(model)
ctrl=get_param([model '/MATLAB Function3'],'PortHandles');
ports=[4 5 8 9]; labels={'P','Q','sp','sq'};
for j=1:numel(ports)
    logport(model,ctrl.Outport(ports(j)),labels{j},j);
end
for pair={'Scope4','Scope1';'I','Vdc'}
    ph=get_param([model '/' pair{1}],'PortHandles');
    line=get_param(ph.Inport(1),'Line');
    assert(line~=-1,'DPCMapping:Logging','Required scope has no input.');
    source=get_param(line,'SrcPortHandle');
    logport(model,source,pair{2},5+strcmp(pair{2},'Vdc'));
end
end

function logport(model,source,label,slot)
path=[model '/Mapping_Log_' label];
if getSimulinkBlockHandle(path)~=-1, delete_block(path); end
add_block('simulink/Sinks/To Workspace',path, ...
    'VariableName',['map_' label],'SaveFormat','Structure With Time', ...
    'MaxDataPoints','inf','Decimation','1', ...
    'Position',[1450 50+60*slot 1550 75+60*slot]);
ph=get_param(path,'PortHandles');
add_line(model,source,ph.Inport(1),'autorouting','on');
end

function m=analyze(raw)
% Identical settled window: five 50 Hz cycles [0.30,0.40), Fs=40 kHz.
% Window choice is explicit, not an automatic guarantee of settling.
ts=1/40000; t=(0.30:ts:(0.40-ts))';
p=sample(raw.P,t); q=sample(raw.Q,t);
i=sample(raw.I,t); v=sample(raw.Vdc,t);
assert(size(i,2)==3,'DPCMapping:Current','Expected three current phases.');
assert(all(isfinite([p(:);q(:);i(:);v(:)])), ...
    'DPCMapping:Finite','Nonfinite output: inspect controller/plant.');
for c={'sp','sq'}
    levels=raw.(c{1}).signals.values;
    assert(all(ismember(levels(:),[-1 0 1])), ...
        'DPCMapping:Levels','Decision outside {-1,0,+1}.');
end
m.P_mean_W=mean(p); m.P_ripple_RMS_W=sqrt(mean((p-mean(p)).^2));
m.P_ripple_pp_W=max(p)-min(p);
m.Q_mean_var=mean(q); m.Q_ripple_RMS_var=sqrt(mean((q-mean(q)).^2));
m.Q_ripple_pp_var=max(q)-min(q);
m.Vdc_mean_V=mean(v); m.Vdc_ripple_pp_V=max(v)-min(v);
n=size(i,1); a=2*abs(fft(i-mean(i,1),[],1))/n;
% 5 cycles in the analysis window: fundamental FFT bin index 6 in MATLAB.
f0bin=5; fundamental=a(f0bin+1,:);
assert(all(fundamental>1e-9),'DPCMapping:Fundamental','Current fundamental too small.');
harmonics=(2:40)*f0bin+1; % Harmonics 2..40, up to 2 kHz, no DC.
thd=100*sqrt(sum(a(harmonics,:).^2,1))./fundamental;
m.Ia_THD_2kHz_pct=thd(1); m.Ib_THD_2kHz_pct=thd(2); m.Ic_THD_2kHz_pct=thd(3);
% Broadband residual includes harmonics and other content up to Nyquist.
total=mean((i-mean(i,1)).^2,1); fundamentalPower=fundamental.^2/2;
residual=100*sqrt(max(0,total-fundamentalPower)./fundamentalPower);
m.Ia_THDN_Nyquist_pct=residual(1);
end

function v=sample(s,t)
x=double(s.signals.values);
x=reshape(x,numel(s.time),[]);
[time,keep]=unique(double(s.time(:)),'last'); x=x(keep,:);
assert(time(1)<=t(1) && time(end)>=t(end), ...
    'DPCMapping:Window','Simulation does not cover the analysis window.');
v=interp1(time,x,t,'previous');
end
