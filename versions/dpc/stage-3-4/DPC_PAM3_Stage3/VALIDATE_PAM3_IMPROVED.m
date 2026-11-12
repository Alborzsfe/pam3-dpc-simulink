function VALIDATE_PAM3_IMPROVED()
% Executable MATLAB checks. Separate from Simulink performance claims.
root=fileparts(mfilename('fullpath'));addpath(root);addpath(fullfile(root,'tests'));
stream=RandStream('mt19937ar','Seed',321);
boundaries=[0 .01 -.01 .005 -.005 .01-eps .01+eps -.01-eps -.01+eps];
e=[boundaries, .04*randn(stream,1,100000),1,-1];
s=zeros(8,1); old=0;
for k=1:numel(e)
    [s,y,hi,lo]=pam3_power_step(s,e(k),0,.015);
    old=reference(old,e(k));
    assert(y==old && hi==.01 && lo==.005, ...
        'PAM3Study:Compatibility','Compatibility mismatch at tick %d.',k);
end
s=zeros(8,1);
for k=1:10000
    x=.05*randn(stream);
    [s,y,hi,lo]=pam3_power_step(s,x,.75,.015);
    assert(ismember(y,[-1 0 1]) && hi>=.01 && hi<=.015 && lo>=.005 && lo<=.015);
    if abs(x)>=.025,assert(y==sign(x));end
end
for x=[-.02 .02 -1 1]
    [~,y]=pam3_power_step(zeros(8,1),x,.75,.015);
    assert(y==sign(x),'PAM3Study:Plateau','Wrong first decision for constant error.');
end
% Whole-controller equivalence: all ten outputs, including gates and sectors.
work=tempname;mkdir(work);addpath(work);cleanup=onCleanup(@()finish(work)); %#ok<NASGU>
code=fileread(fullfile(root,'controllers','fast_template.m'));
keys={'__SEED__','__NOISE_P__','__NOISE_Q__','__GAIN__','__NOISE_FLOOR__'};
values={'321','0','0','0','0.015'};
for k=1:numel(keys),code=strrep(code,keys{k},values{k});end
code=strrep(code,'fcn(v_abc,i_abc,Pref,Qref)','compatible_test(v_abc,i_abc,Pref,Qref)');
fid=fopen(fullfile(work,'compatible_test.m'),'w');assert(fid>=0);
fwrite(fid,code,'char');fclose(fid);clear compatible_test professor_controller
for k=1:4000
    v=70.7*randn(stream,3,1);i=4*randn(stream,3,1);
    pref=400*randn(stream);qref=10*randn(stream);
    if mod(k,100)==0,pref=0;qref=0;end
    a=cell(1,10);b=a;
    [a{:}]=professor_controller(v,i,pref,qref);
    [b{:}]=compatible_test(v,i,pref,qref);
    assert(isequal(a,b),'PAM3Study:WholeController','Output mismatch at tick %d.',k);
end
% Predictor checks: disabled correction exactly passes through measurements;
% active correction is bounded and never overrides large raw tracking errors.
obs=zeros(8,1);
for k=1:4000
    pobs=400+30*randn(stream);qobs=30*randn(stream);
    [obs,pu,qu]=pam3_power_predict(obs,pobs,qobs,400,0,70,0,150,[1;0;0], ...
        1/40000,.2,.015,0);
    assert(pu==pobs && qu==qobs);
end
obs=zeros(8,1);
for k=1:4000
    pobs=400+30*randn(stream);qobs=30*randn(stream);
    [obs,pu,qu]=pam3_power_predict(obs,pobs,qobs,400,0,70,0,150,[1;0;0], ...
        1/40000,.2,.015,.8);
    assert(abs(pu-pobs)<=12+1e-10 && abs(qu-qobs)<=12+1e-10);
    if abs((400-pobs)/400)>=.05,assert(pu==pobs);end
    if abs(qobs/400)>=.05,assert(qu==qobs);end
end
fprintf('PASS: %d core compatibility samples; bounds/steps; 4000 whole-controller ticks; predictor pass-through/bounds.\n',numel(e));
fprintf('This validates logic only; run RUN_PAM3_STUDY for converter performance.\n');
end
function y=reference(old,e)
if old==0
    if e>=.01,y=1;elseif e<=-.01,y=-1;else,y=0;end
elseif old==1
    if e<=-.01,y=-1;elseif e<=.005,y=0;else,y=1;end
else
    if e>=.01,y=1;elseif e>=-.005,y=0;else,y=-1;end
end
end
function finish(work)
clear compatible_test professor_controller
rmpath(work);rmdir(work,'s');
end
