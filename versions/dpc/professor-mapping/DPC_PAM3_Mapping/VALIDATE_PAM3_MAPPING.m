function VALIDATE_PAM3_MAPPING()
% Execute the mapped controller in MATLAB and compare BOTH channels with
% separate states of the original receiver. Does not require Simulink.
root=fileparts(mfilename('fullpath'));
addpath(fullfile(root,'PAM3_original'));
work=tempname; mkdir(work); addpath(work);
cleanup=onCleanup(@()finish(work)); %#ok<NASGU>
code=fileread(fullfile(root,'controller_pam3.m'));
code=strrep(code,'fcn(v_abc,i_abc,Pref,Qref)', ...
    'mapped_receiver_test(v_abc,i_abc,Pref,Qref)');
fid=fopen(fullfile(work,'mapped_receiver_test.m'),'w');
assert(fid>=0); fwrite(fid,code,'char'); fclose(fid);
clear mapped_receiver_test
cfg=pam3_config(); a=pam3_initial_state(cfg); b=a; hp=0; hq=0;
stream=RandStream('mt19937ar','Seed',321);
n=4000; k=(0:n-1)';
ep=0.04*sin(2*pi*k/137)+0.004*randn(stream,n,1);
eq=0.03*sin(2*pi*k/211)+0.004*randn(stream,n,1);
ep(1:40)=0; eq(1:40)=0;
ep(41:90)=1; eq(41:90)=-1; % include ADC clipping and startup latency
v=[1;-.5;-.5]; validCount=0;
for j=1:n
    P=100*(1-ep(j)); Q=-100*eq(j);
    alpha=P/1.5; beta=-Q/1.5;
    current=[alpha;-.5*alpha+sqrt(3)/2*beta;-.5*alpha-sqrt(3)/2*beta];
    [~,~,~,~,~,eP,eQ,sp,sq]=mapped_receiver_test(v,current,100,0);
    adcp=min(255,max(0,floor(117.5+2250*eP+0.5)));
    adcq=min(255,max(0,floor(117.5+2250*eQ+0.5)));
    [a,yP]=pam3_step(a,adcp,1,cfg); [b,yQ]=pam3_step(b,adcq,1,cfg);
    if yP(1), hp=yP(2); validCount=validCount+1; end
    if yQ(1), hq=yQ(2); end
    assert(sp==hp && sq==hq,'DPCMapping:Fidelity', ...
        'Mapped output differs from original receiver at tick %d.',j);
end
assert(validCount>0,'DPCMapping:NoSymbols','No final symbols produced.');
fprintf('PASS: %d ticks, two independent receivers, causal final-symbol hold.\n',n);
end
function finish(work)
clear mapped_receiver_test
rmpath(work); rmdir(work,'s');
end
