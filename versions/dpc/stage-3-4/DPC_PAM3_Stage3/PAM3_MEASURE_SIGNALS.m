function m=PAM3_MEASURE_SIGNALS(raw,cfg)
N=round(diff(cfg.window)/cfg.Ts);
t=cfg.window(1)+((0:N-1)'+0.5)*cfg.Ts;
p=PAM3_SAMPLE(raw.P,t);q=PAM3_SAMPLE(raw.Q,t);i=PAM3_SAMPLE(raw.I,t);
v=PAM3_SAMPLE(raw.Vdc,t);pref=PAM3_SAMPLE(raw.Pref,t);
assert(size(i,2)==3 && all(isfinite([p(:);q(:);i(:);v(:);pref(:)])), ...
 'PAM3Study:Data','Wrong dimensions or nonfinite output.');
m.P_mean_W=mean(p);m.P_ripple_RMS_W=std(p,1);m.P_ripple_pp_W=max(p)-min(p);
m.P_tracking_RMS_W=sqrt(mean((p-pref).^2));
m.Q_mean_var=mean(q);m.Q_ripple_RMS_var=std(q,1);m.Q_ripple_pp_var=max(q)-min(q);
qref=PAM3_SAMPLE(raw.Qref,t);
m.Q_tracking_RMS_var=sqrt(mean((q-qref).^2));
m.Vdc_mean_V=mean(v);m.Vdc_ripple_pp_V=max(v)-min(v);
m.I_peak_A=max(abs(i(:)));m.I_RMS_A=mean(sqrt(mean(i.^2,1)));
a=2*abs(fft(i-mean(i,1),[],1))/N;
fundBin=round(cfg.fundamentalHz*N*cfg.Ts);
assert(abs(fundBin-cfg.fundamentalHz*N*cfg.Ts)<1e-8, ...
 'PAM3Study:Cycles','FFT window must contain an integer number of grid cycles.');
assert(cfg.maxHarmonic*fundBin<N/2,'PAM3Study:Bandwidth','Harmonic cutoff exceeds Nyquist.');
f=a(fundBin+1,:);assert(all(f>1e-9),'PAM3Study:Fundamental','Current fundamental too small.');
thd=100*sqrt(sum(a((2:cfg.maxHarmonic)*fundBin+1,:).^2,1))./f;
residual=100*sqrt(max(0,mean((i-mean(i,1)).^2,1)-f.^2/2)./(f.^2/2));
m.Ia_THD_pct=thd(1);m.Ib_THD_pct=thd(2);m.Ic_THD_pct=thd(3);m.I_THD_mean_pct=mean(thd);
voltage=PAM3_SAMPLE(raw.V,t);
av=2*abs(fft(voltage-mean(voltage,1),[],1))/N;
vf=av(fundBin+1,:);
vthd=100*sqrt(sum(av((2:cfg.maxHarmonic)*fundBin+1,:).^2,1))./vf;
m.V_THD_mean_pct=mean(vthd);
m.Va_THD_pct=vthd(1);m.Vb_THD_pct=vthd(2);m.Vc_THD_pct=vthd(3);
m.Ia_THDN_pct=residual(1);m.Ib_THDN_pct=residual(2);m.Ic_THDN_pct=residual(3);
commutations=0;legCycles=zeros(1,3);
for k=1:3
    g=PAM3_SAMPLE(raw.(['S' num2str(k)]),t);
    assert(all(ismember(g,[0 1])),'PAM3Study:Gates','Invalid switch gate.');
    nchanges=sum(diff(g)~=0);
    commutations=commutations+nchanges;
    legCycles(k)=nchanges/(2*diff(cfg.window));
end
m.SwitchCyclesPerLeg_Hz=commutations/(6*diff(cfg.window));
m.SwitchLegA_Hz=legCycles(1);m.SwitchLegB_Hz=legCycles(2);m.SwitchLegC_Hz=legCycles(3);
nv=PAM3_SAMPLE(raw.NoiseV,t);ni=PAM3_SAMPLE(raw.NoiseI,t);
m.InjectedNoiseVoltage_RMS_V=sqrt(mean(nv(:).^2));
m.InjectedNoiseCurrent_RMS_A=sqrt(mean(ni(:).^2));
sp=PAM3_SAMPLE(raw.sp,t);sq=PAM3_SAMPLE(raw.sq,t);
m.P_DecisionChanges=sum(diff(sp)~=0);m.Q_DecisionChanges=sum(diff(sq)~=0);
m.P_DecisionChangesPerSec=m.P_DecisionChanges/diff(cfg.window);
m.Q_DecisionChangesPerSec=m.Q_DecisionChanges/diff(cfg.window);
m.P_window_drift_W=abs(mean(p(1:N/2))-mean(p(N/2+1:end)));
m.Vdc_window_drift_V=abs(mean(v(1:N/2))-mean(v(N/2+1:end)));
% An explicit screening flag; no claim of a formal settling-time test.
m.WindowScreenOK=m.P_window_drift_W<8 && m.Vdc_window_drift_V<0.5;
end
