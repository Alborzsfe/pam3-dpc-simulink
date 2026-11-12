function VALIDATE_PAM3_FULL()
% Logic fixtures only. Run the native converter study for performance claims.
f=pam3_full_feature_config();PAM3_FULL_FEATURE_VECTOR(f);
longName='DPC4_smoke_20261105_103202_550_n1_v3_predictive_full';
shortName=PAM3_SHORT_MODEL_NAME(longName);
assert(numel(shortName)==19 && isvarname(shortName));
assert(strcmp(shortName,PAM3_SHORT_MODEL_NAME(longName)));
assert(~strcmp(shortName,PAM3_SHORT_MODEL_NAME([longName '_different'])));
Ts=1/40000;
off=f;off.adaptiveBand=false;off.confidenceGate=false;off.persistence=false;
p=PAM3_FULL_FEATURE_VECTOR(off);
s=zeros(12,1);expected=0;
boundary=[-.010 -.005 0 .005 .010];
for k=1:100011
    if k<=numel(boundary),e=boundary(k);
    else,e=.08*sin(.173*k)+.03*cos(.057*k);end
    expected=schmitt(expected,e,.01,.005);
    [s,y,h,l]=pam3_feature_step(s,e,e,400,400,Ts,p,true);
    assert(y==expected && h==.01 && l==.005,'PAM3Full:Compatibility','Disabled features changed hysteresis.');
end
% Adaptation must really change the width, while staying bounded.
a=off;a.adaptiveBand=true;a.startupWarmup_s=0;
p=PAM3_FULL_FEATURE_VECTOR(a);s=zeros(12,1);
for k=1:3000
    e=.006*(-1)^k;
    [s,~,h,l]=pam3_feature_step(s,e,e,400,400,Ts,p,true);
    assert(h>=.01 && h<=.015 && abs(l-.5*h)<1e-12);
end
assert(h>.0101,'PAM3Full:Adaptation','Adaptive width never changed.');
% Gate rejects a marginal candidate; it accepts a clear one.
a=off;a.confidenceGate=true;a.startupWarmup_s=0;
p=PAM3_FULL_FEATURE_VECTOR(a);
[~,y,~,~,d]=pam3_feature_step(zeros(12,1),.0101,.0101,400,400,Ts,p,true);
assert(y==0 && d(7)==1 && d(3)<p(12));
[~,y,~,~,d]=pam3_feature_step(zeros(12,1),.020,.020,400,400,Ts,p,true);
assert(y==1 && d(7)==0);
% Exactly N eligible consecutive samples, with no future samples.
a=off;a.persistence=true;a.startupWarmup_s=0;
p=PAM3_FULL_FEATURE_VECTOR(a);s=zeros(12,1);
seq=[.02 .02 -.02 .02 .02 .02];answer=[0 0 0 0 0 1];
for k=1:numel(seq)
    [s,y,~,~,d]=pam3_feature_step(s,seq(k),seq(k),400,400,Ts,p,true);
    assert(y==answer(k));
end
assert(d(6)==3 && d(9)==1);
% A confidence rejection must interrupt an otherwise matching sequence.
a.confidenceGate=true;p=PAM3_FULL_FEATURE_VECTOR(a);s=zeros(12,1);
seq=[.02 .02 .0101 .02 .02 .02];answer=[0 0 0 0 0 1];
for k=1:numel(seq)
    [s,y]=pam3_feature_step(s,seq(k),.02,400,400,Ts,p,true);
    assert(y==answer(k));
end
% All three additions are active together and still accept a clear request.
a=f;a.startupWarmup_s=0;p=PAM3_FULL_FEATURE_VECTOR(a);s=zeros(12,1);
for k=1:3
    [s,y]=pam3_feature_step(s,.02,.02,400,400,Ts,p,true);
    assert(y==double(k==3));
end
% Fast paths: large error, startup, changed reference and invalid model inputs.
p=PAM3_FULL_FEATURE_VECTOR(f);
[~,y,h,~,d]=pam3_feature_step(zeros(12,1),.10,.10,400,400,Ts,p,true);
assert(y==1 && h==.01 && d(10)==3);
[~,y,h,~,d]=pam3_feature_step(zeros(12,1),.02,.02,400,400,Ts,p,true);
assert(y==1 && h==.01 && d(10)==1);
a=f;a.startupWarmup_s=0;p=PAM3_FULL_FEATURE_VECTOR(a);
[s,~]=pam3_feature_step(zeros(12,1),0,0,0,400,Ts,p,true);
[~,y,h,~,d]=pam3_feature_step(s,.02,.02,80,80,Ts,p,true);
assert(y==1 && h==.01 && d(10)==2 && d(13)==1);
[~,y,h,~,d]=pam3_feature_step(zeros(12,1),.02,.02,400,400,Ts,p,false);
assert(y==1 && h==.01 && d(10)==4);
whole_controller_off_fixture();
fprintf('PASS: feature bounds, adaptive widths, gate/persistence rules, fast paths, 100011 decisions and 4000 whole-controller compatibility ticks.\n');
end

function y=schmitt(old,e,h,l)
if old==0
    if e>=h,y=1;elseif e<=-h,y=-1;else,y=0;end
elseif old==1
    if e<=-h,y=-1;elseif e<=l,y=0;else,y=1;end
else
    if e>=h,y=1;elseif e>=-l,y=0;else,y=-1;end
end
end

function whole_controller_off_fixture()
root=fileparts(mfilename('fullpath'));cfg=research_stage3_config();
cfg.fullFeatures=pam3_full_feature_config();
cfg.fullFeatures.adaptiveBand=false;cfg.fullFeatures.confidenceGate=false;
cfg.fullFeatures.persistence=false;
work=tempname;mkdir(work);addpath(work);
cleanup=onCleanup(@()finish(work)); %#ok<NASGU>
templates={'predictive','predictive_full'};
names={'stage4_observer_fixture','stage4_disabled_fixture'};
for k=1:2
    template=templates{k};
    code=fileread(fullfile(root,'controllers',[template '_template.m']));
    keys={'__SEED__','__NOISE_P__','__NOISE_Q__','__TS__','__R__','__L__','__BLEND__'};
    values=[321 0 0 cfg.Ts cfg.modelR cfg.modelL cfg.maxObserverBlend];
    for j=1:numel(keys),code=strrep(code,keys{j},num2str(values(j),17));end
    if k==2,code=PAM3_RENDER_FULL_FEATURES(code,cfg);end
    code=PAM3_RENDER_DIAGNOSTICS(code,template,template,cfg);
    code=regexprep(code,'fcn\(',[names{k} '('],'once');
    fid=fopen(fullfile(work,[names{k} '.m']),'w');assert(fid>=0);
    fwrite(fid,code,'char');fclose(fid);
end
clear stage4_observer_fixture stage4_disabled_fixture
for k=1:4000
    t=(k-1)*cfg.Ts;phase=2*pi*50*t+[0;-2*pi/3;2*pi/3];
    v=50*sqrt(2)*sin(phase)+.2*cos(13*phase);
    i=3.75*sin(phase)+.02*cos(17*phase);
    pref=240+160*(k>1500);qref=-80*(k>2500);
    a=cell(1,11);b=a;
    [a{:}]=stage4_observer_fixture(v,i,pref,qref,150);
    [b{:}]=stage4_disabled_fixture(v,i,pref,qref,150);
    assert(isequal(a(1:10),b(1:10)) && isequal(a{11},b{11}(1:14)), ...
        'PAM3Full:WholeController','Disabled feature path changed the prior observer controller.');
    assert(numel(b{11})==42);
end
end

function finish(work)
clear stage4_observer_fixture stage4_disabled_fixture
rmpath(work);rmdir(work,'s');
end
