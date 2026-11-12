function VALIDATE_RESEARCH_STAGE2()
% Pure MATLAB checks; do not claim converter performance.
root=fileparts(mfilename('fullpath'));cfg=research_stage2_config();
% Physical waveform fixture: total THD, each harmonic and phase sequence.
fs=40000;N=4000;v=zeros(N,3);
for k=1:N,v(k,:)=pam3_grid_wave((k-1)/fs,50,50,.05)';end
a=2*abs(fft(v))/N;fund=5;
thd=sqrt(a(5*fund+1,:).^2+a(7*fund+1,:).^2)./a(fund+1,:);
assert(max(abs(thd-.05))<1e-10,'PAM3Study:GridFixture','Wrong grid THD.');
F=fft(v);
assert(abs(angle(F(5*fund+1,2)/F(5*fund+1,1))-2*pi/3)<1e-10);
assert(abs(angle(F(7*fund+1,2)/F(7*fund+1,1))+2*pi/3)<1e-10);
[p,q]=pam3_reference_profile(.099,.1,240,400,0,80);assert(p==240 && q==0);
[p,q]=pam3_reference_profile(.100,.1,240,400,0,80);assert(p==400 && q==80);
b=struct('SwitchLegA_Hz',4000,'SwitchLegB_Hz',4000, ...
 'SwitchLegC_Hz',4000,'SwitchCyclesPerLeg_Hz',4000,'I_THD_mean_pct',999);
p=b;p.I_THD_mean_pct=.01;
assert(PAM3_SWITCH_SCORE({b},{p})==0,'PAM3Study:Calibration','Score depends on quality.');
b.SwitchLegA_Hz=4400;
assert(abs(PAM3_SWITCH_SCORE({b},{p})-400/4400)<1e-12);
% Diagnostic output must not change the original controller's first 10 ports.
work=tempname;mkdir(work);addpath(work);addpath(fullfile(root,'tests'));
cleanup=onCleanup(@()finish(work)); %#ok<NASGU>
for template={'baseline','predictive'}
 code=fileread(fullfile(root,'controllers',[template{1} '_template.m']));
 c=cfg;c.baselineBandScale=1;
 code=PAM3_RENDER_DIAGNOSTICS(code,template{1},template{1},c);
 keys={'__SEED__','__NOISE_P__','__NOISE_Q__','__TS__','__R__','__L__','__BLEND__'};
 values=[321 0 0 cfg.Ts cfg.modelR cfg.modelL cfg.maxObserverBlend];
 for k=1:numel(keys),code=strrep(code,keys{k},num2str(values(k),17));end
 name=['stage2_' template{1}];code=regexprep(code,'fcn\(',[name '('],'once');
 fid=fopen(fullfile(work,[name '.m']),'w');assert(fid>=0);fwrite(fid,code,'char');fclose(fid);
end
clear stage2_baseline stage2_predictive professor_controller
for k=1:1000
 phase=2*pi*50*(k-1)/40000+[0;-2*pi/3;2*pi/3];
 v=50*sqrt(2)*sin(phase);i=3.75*sin(phase);
 a=cell(1,10);b=cell(1,11);z=b;
 [a{:}]=professor_controller(v,i,400,0);
 [b{:}]=stage2_baseline(v,i,400,0);
 assert(isequal(a,b(1:10)),'PAM3Study:Diagnostics','Baseline outputs changed.');
 [z{:}]=stage2_predictive(v,i,400,0,150);d=z{11};
 assert(numel(d)==14 && max(abs(d(5:8)-[.01;.005;.01;.005]))<1e-12);
 assert(abs(d(3)-(d(1)-d(9)))<1e-12 && abs(d(4)-(d(2)-d(10)))<1e-12);
end
% Dynamic metrics fixture: ideal instantaneous step has zero overshoot/error.
cfg.stopTime=.25;cfg.Ts=1/40000;t=(0:cfg.Ts:cfg.stopTime)';
y=240+160*(t>=cfg.stepTime);s=struct('time',t,'signals',struct('values',y));
raw.P=s;raw.Pref=s;raw.Vdc=s;raw.Vdc.signals.values=150*ones(size(t));
d=PAM3_DYNAMIC_METRICS(raw,cfg,'P');
assert(d.PeakOvershoot_pct==0 && d.FinalMeanError==0 && d.IntegralAbsError==0);
assert(d.RiseTime10to90_s==0 && d.InstantaneousSettlingTime_s<cfg.Ts);
fprintf('PASS: waveform/reference fixtures, switching-only score, diagnostic invariance and dynamic metrics.\n');
end
function finish(work)
clear stage2_baseline stage2_predictive professor_controller
rmpath(work);rmdir(work,'s');
end
