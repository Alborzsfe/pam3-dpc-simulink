function [state, decision, hEnter, hExit] = pam3_power_step(state, errorPu, gain, noiseFloor)
%#codegen
% CONTROL adaptation inspired by four programmable/dynamic patent thresholds.
% This is NOT the Ethernet receiver or an exact equation from the patent.
% state = [decision; e(k-1); e(k-2); blockSum; blockN; noiseVar; ready; ticks].
% No ADC quantization, symbol clock, lookahead, data-dependent output hold,
% DC-bias cancellation or scheduled output delay.
hEnter = 0.010;
hExit = 0.005;
e = errorPu;
if ~isfinite(e)
    error('PAM3Power:Nonfinite','Nonfinite power error.');
end
if state(7) == 0
    state(2) = e; state(3) = e; state(7) = 1;
end
% Bound the high-frequency indicator, so one large reference step does not
% widen the band for a long time. Switching ripple ALSO contributes to this
% indicator: it is not an oracle/noise-only estimator.
d2 = e - 2*state(2) + state(3);
d2 = min(0.060,max(-0.060,d2));
state(4) = state(4) + d2*d2/6;
state(5) = state(5) + 1;
if state(5) == 12
    state(6) = state(6) + (state(4)/12 - state(6))/8;
    state(4) = 0; state(5) = 0;
end
state(8) = min(2000,state(8)+1); % first 50 ms: original bands
state(3) = state(2); state(2) = e;
% Disabled gain gives EXACT professor hysteresis decisions, including >=/<=.
% The added entry band is limited to 0.005 pu (0.5 percentage points).
if gain > 0 && abs(e) < 0.025 && state(8) >= 2000
    sigma = sqrt(max(0,state(6)));
    extra = min(0.005,max(0,gain*(sigma-noiseFloor)));
    hEnter = hEnter + extra;
    hExit = hExit + 0.5*extra;
end
old = state(1);
if old == 0
    if e >= hEnter, decision = 1;
    elseif e <= -hEnter, decision = -1;
    else, decision = 0; end
elseif old == 1
    if e <= -hEnter, decision = -1;
    elseif e <= hExit, decision = 0;
    else, decision = 1; end
else
    if e >= hEnter, decision = 1;
    elseif e >= -hExit, decision = 0;
    else, decision = -1; end
end
state(1) = decision;
end
