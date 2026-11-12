function [vmeas,imeas,Ptrue,Qtrue,nv,ni]=fcn(vtrue,itrue)
%#codegen
% Measurement-path noise ONLY. The electrical source is unchanged.
persistent seed
if isempty(seed),seed=__SEED__;end
[seed,vmeas,imeas,nv,ni]=pam3_sensor_step(seed,vtrue,itrue,__SIGMA_V__,__SIGMA_I__);
va=(2/3)*(vtrue(1)-.5*vtrue(2)-.5*vtrue(3));
vb=(sqrt(3)/3)*(vtrue(2)-vtrue(3));
ia=(2/3)*(itrue(1)-.5*itrue(2)-.5*itrue(3));
ib=(sqrt(3)/3)*(itrue(2)-itrue(3));
Ptrue=1.5*(va*ia+vb*ib);Qtrue=1.5*(vb*ia-va*ib);
end
