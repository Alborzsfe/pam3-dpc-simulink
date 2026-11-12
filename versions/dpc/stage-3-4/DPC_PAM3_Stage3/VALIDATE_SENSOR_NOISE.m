function VALIDATE_SENSOR_NOISE()
% Standalone checks; no converter performance claims.
cfg=pam3_study_config();
s1=321;s2=321;ss=654;nv=zeros(3,12000);ni=nv;different=false;
for k=1:size(nv,2)
    v=[70;-35;-35];i=[3;-1;-2];
    [s1,vm,im,nv(:,k),ni(:,k)]=pam3_sensor_step(s1,v,i,.5,.05);
    [s2,v2,i2]=pam3_sensor_step(s2,v,i,.5,.05);
    assert(isequal(vm,v2) && isequal(im,i2),'PAM3Study:Repeatability','Noise differs.');
    assert(max(abs(vm-v-nv(:,k)))<1e-12 && max(abs(im-i-ni(:,k)))<1e-12);
    [ss,other]=pam3_sensor_step(ss,v,i,.5,.05);
    different=different || ~isequal(other,vm);
end
assert(different);
expected=[-0.12990775844082236;0.29403442377224565;-0.15909346332773566;-0.079521087277680647;0.0065637334249913698;-0.063063776213675746];
assert(max(abs([nv(:,1);ni(:,1)]-expected))<1e-14, ...
    'PAM3Study:NoiseFixture','First sensor-noise tick differs from arithmetic fixture.');
assert(abs(std(nv(:),1)-.5)<.025 && abs(std(ni(:),1)-.05)<.0025);
assert(abs(mean(nv(:)))<.015 && abs(mean(ni(:)))<.0015);
[~,vm,im]=pam3_sensor_step(321,v,i,0,0);
assert(isequal(vm,v) && isequal(im,i),'PAM3Study:Clean','Clean input changed.');
% Guard against accepting aggregate switching equality that hides one leg.
b=struct('Method',"baseline",'Seed',321,'SamplingFrequency_Hz',40000, ...
 'FilterInductance_H',.015,'NoiseVoltageStd_V',.5,'NoiseCurrentStd_A',.05, ...
 'I_THD_mean_pct',2,'P_ripple_RMS_W',10,'Q_ripple_RMS_var',10, ...
 'Ia_THD_pct',2,'Ib_THD_pct',2,'Ic_THD_pct',2, ...
 'Ia_THDN_pct',4,'Ib_THDN_pct',4,'Ic_THDN_pct',4, ...
 'SwitchCyclesPerLeg_Hz',4000,'SwitchLegA_Hz',4000,'SwitchLegB_Hz',4000, ...
 'SwitchLegC_Hz',4000,'P_mean_W',400,'Q_mean_var',0,'Vdc_mean_V',150, ...
 'P_tracking_RMS_W',12,'WindowScreenOK',true);
a=b;a.Method="predictive";a.I_THD_mean_pct=1.5;
c=PAM3_COMPARE_CASES(b,a,cfg);assert(c.UsefulAtComparableSwitching);
a.SwitchLegA_Hz=4400;a.SwitchLegB_Hz=3600;
c=PAM3_COMPARE_CASES(b,a,cfg);assert(c.QualityUseful && ~c.SwitchingComparable);
a=b;a.I_THD_mean_pct=1.5;a.SwitchCyclesPerLeg_Hz=4400;
c=PAM3_COMPARE_CASES(b,a,cfg);assert(c.QualityUseful && ~c.UsefulAtComparableSwitching);
fprintf('PASS: six-channel sensor noise repeatability, levels, zero-noise and switching gates.\n');
end
