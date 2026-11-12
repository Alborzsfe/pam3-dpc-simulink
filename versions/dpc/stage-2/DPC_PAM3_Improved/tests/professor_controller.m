
function [S1,S2,S3,P,Q,eP_pu,eQ_pu,sp,sq,sec] = ...
    professor_controller(v_abc,i_abc,Pref,Qref)
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

eP_pu = (Pref - P)/Pbase;
eQ_pu = (Qref - Q)/Qbase;

%% ============================================================
% THREE-LEVEL ACTIVE-POWER HYSTERESIS
% =============================================================

if sp_old == 0

    if eP_pu >= hP_in
        sp = 1;
    elseif eP_pu <= -hP_in
        sp = -1;
    else
        sp = 0;
    end

elseif sp_old == 1

    if eP_pu <= -hP_in
        sp = -1;
    elseif eP_pu <= hP_out
        sp = 0;
    else
        sp = 1;
    end

else

    if eP_pu >= hP_in
        sp = 1;
    elseif eP_pu >= -hP_out
        sp = 0;
    else
        sp = -1;
    end
end

%% ============================================================
% THREE-LEVEL REACTIVE-POWER HYSTERESIS
% =============================================================

if sq_old == 0

    if eQ_pu >= hQ_in
        sq = 1;
    elseif eQ_pu <= -hQ_in
        sq = -1;
    else
        sq = 0;
    end

elseif sq_old == 1

    if eQ_pu <= -hQ_in
        sq = -1;
    elseif eQ_pu <= hQ_out
        sq = 0;
    else
        sq = 1;
    end

else

    if eQ_pu >= hQ_in
        sq = 1;
    elseif eQ_pu >= -hQ_out
        sq = 0;
    else
        sq = -1;
    end
end

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
