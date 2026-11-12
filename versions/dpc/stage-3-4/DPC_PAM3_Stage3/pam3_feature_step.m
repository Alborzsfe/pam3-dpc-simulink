function [s,y,hEnter,hExit,d]=pam3_feature_step(s,e,rawE,reference,base,Ts,p,inputsValid)
%#codegen
% Causal ternary Schmitt decisions with independently enabled additions.
% s = [committed; raw(k-1); raw(k-2); indicatorVariance; extraBand;
%      pending; count; elapsed_s; oldReference; oldBase; initialized; guard_s].
% The high-frequency indicator includes switching ripple and model error.
% Confidence is a normalized boundary margin, NOT a calibrated probability.
if ~isfinite(e) || ~isfinite(rawE) || ~isfinite(reference) || ...
        ~isfinite(base) || base<=0 || ~isfinite(Ts) || Ts<=0
    error('PAM3Full:Input','Invalid decision input or sample time.');
end
if s(11)==0
    s(2)=rawE;s(3)=rawE;s(9)=reference;s(10)=base;s(11)=1;
end
old=s(1);
referenceChanged=reference~=s(9) || base~=s(10);
if referenceChanged
    % Do not interpret an intentional setpoint/base change as sensor noise.
    s(2)=rawE;s(3)=rawE;s(4)=0;s(5)=0;
    s(6)=old;s(7)=0;s(12)=p(16);
end
% Previous samples only: no future symbols, lookahead, or centered filtering.
d2=min(p(17),max(-p(17),rawE-2*s(2)+s(3)));
alphaNoise=1-exp(-Ts/p(9));
if s(12)<=0
    s(4)=min(p(18)^2,max(0,s(4)+alphaNoise*(d2*d2/6-s(4))));
end
sigma=sqrt(max(0,s(4)));
s(3)=s(2);s(2)=rawE;s(9)=reference;s(10)=base;
bypassReason=0;
if s(8)<p(11),bypassReason=1;end
if s(12)>0,bypassReason=2;end
if max(abs(e),abs(rawE))>=p(15),bypassReason=3;end
if ~inputsValid,bypassReason=4;end
ready=bypassReason==0;
targetExtra=0;
if p(1)>0 && ready
    targetExtra=min(p(7),max(0,p(6)*(sigma-p(8))));
end
alphaBand=1-exp(-Ts/p(10));
s(5)=min(p(7),max(0,s(5)+alphaBand*(targetExtra-s(5))));
appliedExtra=0;
if p(1)>0 && ready,appliedExtra=s(5);end
hEnter=p(4)+appliedExtra;
hExit=p(5)+(p(5)/p(4))*appliedExtra;
% Same inclusive boundary convention as the original professor controller.
candidate=old;margin=0;
if old==0
    if e>=hEnter,candidate=1;margin=e-hEnter;
    elseif e<=-hEnter,candidate=-1;margin=-hEnter-e;end
elseif old==1
    if e<=-hEnter,candidate=-1;margin=-hEnter-e;
    elseif e<=hExit,candidate=0;margin=hExit-e;end
else
    if e>=hEnter,candidate=1;margin=e-hEnter;
    elseif e>=-hExit,candidate=0;margin=e+hExit;end
end
score=0;gatePassed=true;gateRejected=false;waiting=false;
countForTrace=0;y=old;
if candidate==old
    s(6)=old;s(7)=0;
else
    score=margin/max(sigma,p(13));
    if p(2)>0 && ready,gatePassed=score>=p(12);end
    if ~gatePassed
        % Rejection breaks the sequence of eligible consecutive samples.
        gateRejected=true;s(6)=old;s(7)=0;
    elseif p(3)>0 && ready
        if s(6)==candidate,s(7)=s(7)+1;
        else,s(6)=candidate;s(7)=1;end
        countForTrace=s(7);
        if s(7)>=p(14)
            y=candidate;s(6)=candidate;s(7)=0;
        else
            waiting=true;
        end
    else
        y=candidate;s(6)=candidate;s(7)=0;
    end
end
s(1)=y;s(8)=min(p(11)+Ts,s(8)+Ts);
s(12)=max(0,s(12)-Ts);
% [sigma; bandTarget; confidenceScore; candidate; gatePassed; count;
%  gateRejected; persistenceWaiting; acceptedChange; bypassReason;
%  rawErrorPu; appliedExtraBand; referenceChanged; ready].
d=[sigma;targetExtra;score;candidate;double(gatePassed);countForTrace; ...
    double(gateRejected);double(waiting);double(y~=old);bypassReason; ...
    rawE;appliedExtra;double(referenceChanged);double(ready)];
end
