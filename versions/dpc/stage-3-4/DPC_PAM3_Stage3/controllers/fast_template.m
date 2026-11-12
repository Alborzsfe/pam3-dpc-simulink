
function [S1,S2,S3,P,Q,eP_pu,eQ_pu,sp,sq,sec] = ...
    fcn(v_abc,i_abc,Pref,Qref)
%#codegen
%
% Three-Level Hysteresis Direct Power Control
% Two-Level Three-Phase Converter
% 12-Sector Switching Table
%
% sp, sq = -1, 0, +1
% S1, S2, S3: Upper-switch commands

%% ============================================================
% THREE-LEVEL HYSTERESIS BANDS
% =============================================================

hP_in  = 0.010;
hQ_in  = 0.010;

hP_out = 0.005;
hQ_out = 0.005;

%% ============================================================
% PERSISTENT MEMORY
% =============================================================

persistent sp_old sq_old lastP lastQ
persistent S1_old S2_old S3_old valid_old

if isempty(sp_old)
    sp_old = 0;
    sq_old = 0;

    lastP = -1;
    lastQ = -1;

    S1_old = 0;
    S2_old = 0;
    S3_old = 0;

    valid_old = false;
end

%% ============================================================
% ABC TO ALPHA-BETA
% =============================================================

va = v_abc(1);
vb = v_abc(2);
vc = v_abc(3);

v_alpha = (2/3)*(va - 0.5*vb - 0.5*vc);
v_beta  = (sqrt(3)/3)*(vb - vc);

ia = i_abc(1);
ib = i_abc(2);
ic = i_abc(3);

i_alpha = (2/3)*(ia - 0.5*ib - 0.5*ic);
i_beta  = (sqrt(3)/3)*(ib - ic);

%% ============================================================
% INSTANTANEOUS POWER
% =============================================================

P = 1.5*(v_alpha*i_alpha + v_beta*i_beta);

Q = 1.5*(v_beta*i_alpha - v_alpha*i_beta);

%% ============================================================
% POWER BASES
% =============================================================

Pbase = abs(Pref);

if Pbase < 1
    Pbase = 1;
end

if abs(Qref) >= 1
    Qbase = abs(Qref);
else
    Qbase = Pbase;
end

%% ============================================================
% PER-UNIT ERRORS
% =============================================================

% Identical deterministic measurement-noise realization in every variant.
% Physical P/Q above are retained for honest performance measurements.
persistent studySeed
if isempty(studySeed), studySeed = __SEED__; end
[studySeed, noiseP, noiseQ] = study_noise(studySeed);
Pctrl = P + __NOISE_P__ * noiseP;
Qctrl = Q + __NOISE_Q__ * noiseQ;

eP_pu = (Pref - Pctrl)/Pbase;
eQ_pu = (Qref - Qctrl)/Qbase;

%% FAST CONTROL-SPECIFIC FOUR-THRESHOLD DETECTOR
persistent powerStateP powerStateQ
if isempty(powerStateP)
    powerStateP=zeros(8,1); powerStateQ=zeros(8,1);
end
[powerStateP,sp] = pam3_power_step(powerStateP,eP_pu,__GAIN__,__NOISE_FLOOR__);
[powerStateQ,sq] = pam3_power_step(powerStateQ,eQ_pu,__GAIN__,__NOISE_FLOOR__);

%% ============================================================
% 12-SECTOR IDENTIFICATION
% =============================================================

theta = atan2(v_beta,v_alpha);

if (theta > 0) && (theta <= pi/6)
    sec = 1;

elseif (theta > pi/6) && (theta <= pi/3)
    sec = 2;

elseif (theta > pi/3) && (theta <= pi/2)
    sec = 3;

elseif (theta > pi/2) && (theta <= 2*pi/3)
    sec = 4;

elseif (theta > 2*pi/3) && (theta <= 5*pi/6)
    sec = 5;

elseif (theta > 5*pi/6) && (theta <= pi)
    sec = 6;

elseif (theta >= -pi) && (theta <= -5*pi/6)
    sec = 7;

elseif (theta > -5*pi/6) && (theta <= -2*pi/3)
    sec = 8;

elseif (theta > -2*pi/3) && (theta <= -pi/2)
    sec = 9;

elseif (theta > -pi/2) && (theta <= -pi/3)
    sec = 10;

elseif (theta > -pi/3) && (theta <= -pi/6)
    sec = 11;

else
    sec = 12;
end

%% ============================================================
% NINE-STATE SWITCHING SELECTION
% =============================================================

% When both power decisions are zero,
% hold the previously applied switching vector.

if (sp == 0) && (sq == 0) && valid_old

    S1 = S1_old;
    S2 = S2_old;
    S3 = S3_old;

else

    % Remember the latest nonzero directions.

    if sp ~= 0
        lastP = sp;
    end

    if sq ~= 0
        lastQ = sq;
    end

    dP = lastP;
    dQ = lastQ;

    %% --------------------------------------------------------
    % ORIGINAL SWITCHING VECTORS
    %
    % V1 = [1 0 0]
    % V2 = [1 1 0]
    % V3 = [0 1 0]
    % V4 = [0 1 1]
    % V5 = [0 0 1]
    % V6 = [1 0 1]
    %
    % Row 1: dP=+1, dQ=+1
    % Row 2: dP=+1, dQ=-1
    % Row 3: dP=-1, dQ=+1
    % Row 4: dP=-1, dQ=-1
    %% --------------------------------------------------------

    vector_table = [ ...
        4 4 5 5 6 6 1 1 2 2 3 3;
        6 6 1 1 2 2 3 3 4 4 5 5;
        2 2 3 3 4 4 5 5 6 6 1 1;
        1 1 2 2 3 3 4 4 5 5 6 6
    ];

    %% --------------------------------------------------------
    % SELECT SWITCHING TABLE ROW
    %% --------------------------------------------------------

    if dP == 1

        if dQ == 1
            row = 1;
        else
            row = 2;
        end

    else

        if dQ == 1
            row = 3;
        else
            row = 4;
        end
    end

    %% --------------------------------------------------------
    % SELECT VOLTAGE VECTOR
    %% --------------------------------------------------------

    vector_id = vector_table(row,sec);

    switch vector_id

        case 1
            S1 = 1;
            S2 = 0;
            S3 = 0;

        case 2
            S1 = 1;
            S2 = 1;
            S3 = 0;

        case 3
            S1 = 0;
            S2 = 1;
            S3 = 0;

        case 4
            S1 = 0;
            S2 = 1;
            S3 = 1;

        case 5
            S1 = 0;
            S2 = 0;
            S3 = 1;

        otherwise
            S1 = 1;
            S2 = 0;
            S3 = 1;
    end
end

%% ============================================================
% UPDATE SWITCHING MEMORY
% =============================================================

S1_old = S1;
S2_old = S2;
S3_old = S3;

valid_old = true;

end


function [seed, p, q] = study_noise(seed)
% Approximate Gaussian from sum of 12 independent-style LCG uniforms.
% Double integer arithmetic stays below 2^53; no integer saturation ambiguity.
p=0; q=0;
for j=1:12
    seed=mod(1664525*seed+1013904223,4294967296);
    p=p+seed/4294967296;
    seed=mod(1664525*seed+1013904223,4294967296);
    q=q+seed/4294967296;
end
p=p-6; q=q-6;
end

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
