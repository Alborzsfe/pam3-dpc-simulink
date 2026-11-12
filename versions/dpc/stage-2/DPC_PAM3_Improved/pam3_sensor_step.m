function [seed,vmeas,imeas,nv,ni]=pam3_sensor_step(seed,vtrue,itrue,sigmaV,sigmaI)
%#codegen
% Six independent-channel approximate N(0,1) samples, generated every tick.
% sigmaV in volts per phase, sigmaI in amperes per phase (standard deviation).
% State is explicit; no dependence on model solver calls or global RNG.
nv=zeros(3,1);ni=zeros(3,1);
for phase=1:3
    zv=0;zi=0;
    for j=1:12
        seed=mod(1664525*seed+1013904223,4294967296);
        zv=zv+seed/4294967296;
        seed=mod(1664525*seed+1013904223,4294967296);
        zi=zi+seed/4294967296;
    end
    nv(phase)=sigmaV*(zv-6);ni(phase)=sigmaI*(zi-6);
end
vmeas=vtrue(:)+nv;imeas=itrue(:)+ni;
end
