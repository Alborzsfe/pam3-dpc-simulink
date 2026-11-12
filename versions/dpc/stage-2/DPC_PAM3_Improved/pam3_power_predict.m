function [s,Pused,Qused,weightP,weightQ]=pam3_power_predict( ...
    s,Pobs,Qobs,Pref,Qref,va,vb,Vdc,previousSwitch,Ts,R,L,maxBlend)
%#codegen
% Engineering addition for control; NOT a formula from US11405248B2.
% Causal current prediction reduces measurement-noise influence without
% waiting for future samples or symbol timing. Uses measured DC voltage.
% s: [estimated ia/ib, previous va/vb/Vdc, innovation powers P/Q, tick].
Pused=Pobs;Qused=Qobs;weightP=0;weightQ=0;
pbase=max(abs(Pref),1);
if abs(Qref)>=1,qbase=abs(Qref);else,qbase=pbase;end
voltage2=va*va+vb*vb;
if voltage2<1 || ~isfinite(Vdc) || Vdc<=1
    s=zeros(8,1);return; % insufficient measurements: ordinary hysteresis
end
if s(8)==0
    s(3)=va;s(4)=vb;s(5)=Vdc;
end
ua=(2/3)*s(5)*(previousSwitch(1)-.5*previousSwitch(2)-.5*previousSwitch(3));
ub=(sqrt(3)/3)*s(5)*(previousSwitch(2)-previousSwitch(3));
a=exp(-R*Ts/L);b=(1-a)/R;
iaPred=a*s(1)+b*(s(3)-ua);
ibPred=a*s(2)+b*(s(4)-ub);
pPred=1.5*(va*iaPred+vb*ibPred);
qPred=1.5*(vb*iaPred-va*ibPred);
innovationP=Pobs-pPred;innovationQ=Qobs-qPred;
np=min(.05,max(-.05,innovationP/pbase));
nq=min(.05,max(-.05,innovationQ/qbase));
s(6)=s(6)+(np*np-s(6))/96;
s(7)=s(7)+(nq*nq-s(7))/96;
s(8)=min(2001,s(8)+1);
% First 50 ms at 40 kHz uses the unmodified measured errors.
if s(8)>2000
    weightP=min(maxBlend,max(0,(sqrt(max(0,s(6)))-.005)/.020));
    weightQ=min(maxBlend,max(0,(sqrt(max(0,s(7)))-.005)/.020));
end
% Large tracking errors get immediate baseline decisions, including startup
% and significant reference changes. Correction is bounded to 0.03 pu.
if abs((Pref-Pobs)/pbase)<.05
    Pused=Pobs-weightP*min(.03*pbase,max(-.03*pbase,innovationP));
end
if abs((Qref-Qobs)/qbase)<.05
    Qused=Qobs-weightQ*min(.03*qbase,max(-.03*qbase,innovationQ));
end
% Reconstruct the current estimate only from the noisy P/Q that this method
% is allowed to observe, NOT from an uncorrupted current hidden in a test.
s(1)=(va*Pused+vb*Qused)/(1.5*voltage2);
s(2)=(vb*Pused-va*Qused)/(1.5*voltage2);
s(3)=va;s(4)=vb;s(5)=Vdc;
end
