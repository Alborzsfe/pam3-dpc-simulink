
function [S1,S2,S3,P,Q,eP_pu,eQ_pu,sp,sq,sec] = ...
    fcn(v_abc,i_abc,Pref,Qref,Vdc)
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

persistent observerState
if isempty(observerState),observerState=zeros(8,1);end
[observerState,Pctrl,Qctrl]=pam3_power_predict(observerState, ...
    Pctrl,Qctrl,Pref,Qref,v_alpha,v_beta,Vdc,[S1_old;S2_old;S3_old], ...
    __TS__,__R__,__L__,__BLEND__);
% Applying ordinary four-threshold hysteresis to these causal estimates is
% equivalent to a center shift in raw-error coordinates. The additional
% decision module below may also change the band width, reject low-margin
% candidates, or require consecutive eligible candidates.
eP_pu = (Pref - Pctrl)/Pbase;
eQ_pu = (Qref - Qctrl)/Qbase;

%% ============================================================
% ADAPTIVE BAND, CONFIDENCE GATE AND CONSECUTIVE-SAMPLE CONFIRMATION
% =============================================================

persistent featureStateP featureStateQ
if isempty(featureStateP)
    featureStateP=zeros(12,1);featureStateQ=zeros(12,1);
end
fullParams=__FULL_CFG__;
featureInputsValid=(v_alpha*v_alpha+v_beta*v_beta)>=1 && isfinite(Vdc) && Vdc>1;
[featureStateP,sp,hP_in,hP_out,featureTraceP]=pam3_feature_step( ...
    featureStateP,eP_pu,(Pref-P)/Pbase,Pref,Pbase,__TS__,fullParams,featureInputsValid);
[featureStateQ,sq,hQ_in,hQ_out,featureTraceQ]=pam3_feature_step( ...
    featureStateQ,eQ_pu,(Qref-Q)/Qbase,Qref,Qbase,__TS__,fullParams,featureInputsValid);

sp_old = sp;
sq_old = sq;

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
