
function [S1,S2,S3,P,Q,eP_pu,eQ_pu,sp,sq,sec] = ...
    fcn(v_abc,i_abc,Pref,Qref)
%#codegen
%
% Original PAM3 receiver mapped to power errors; simulation integration
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

persistent stateP stateQ heldP heldQ lastP lastQ
persistent S1_old S2_old S3_old valid_old

if isempty(stateP)
    cfg0 = pam3_config();
    stateP = pam3_initial_state(cfg0);
    stateQ = pam3_initial_state(cfg0);
    heldP = 0;
    heldQ = 0;

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

%% ORIGINAL PATENT RECEIVER: TWO INDEPENDENT CHANNELS
% Interface calibration (engineering choice, NOT a patent equation):
% ADC = round(117.5 + 2250 * error_pu), saturated to [0,255].
% Patent plus/minus thresholds 140/95 map nominally to +/- 0.01 pu.
% Strict comparisons, rounding, other thresholds and latency remain intact.
% Original default fixed thresholds are preserved: adaptive_mode=0, DC off.
% One receiver sample per controller execution (Ts_DPC=25 us).
cfg = pam3_config();
adcP = min(255, max(0, floor(117.5 + 2250*eP_pu + 0.5)));
adcQ = min(255, max(0, floor(117.5 + 2250*eQ_pu + 0.5)));
[stateP, traceP] = pam3_step(stateP, adcP, 1, cfg);
[stateQ, traceQ] = pam3_step(stateQ, adcQ, 1, cfg);
% Final valid symbol only. Never use raw/filtered intermediate output,
% future data, historical symbol indices, or end-of-capture tail flush.
if traceP(1) ~= 0
    heldP = traceP(2);
end
if traceQ(1) ~= 0
    heldQ = traceQ(2);
end
sp = heldP;
sq = heldQ;

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

function cfg = pam3_config()
% Explicit reconstruction parameters for US11405248B2.
cfg.sample_time = 1 / 800e6;
cfg.plus = 140;
cfg.minus = 95;
cfg.zero_plus = 160;
cfg.zero_minus = 80;
cfg.dc_enabled = false;
cfg.dc_min_gate = 80;  % Undisclosed constant: documented assumption.
cfg.dc_anchor = 95;   % Literal printed DC equation, including its ambiguity.
cfg.adaptive_mode = 0; % 0=fixed, 1=Q8 hardware rule, 2=original float rule.
cfg.initial_phase = 6;
end


function L = pam3_layout()
% Fixed-length per-channel state. Never grows with capture length.
L.tick = 1; L.length = 2; L.next = 3; L.previous = 4;
L.level = 5; L.initialized = 6; L.dc_filled = 7;
L.filter_initialized = 8; L.previous_filtered = 9;
L.edge_initialized = 10; L.direction = 11; L.last_edge = 12;
L.block_count = 13; L.ending = 14; L.flush_count = 15;
L.thresholds = 16:19; L.means = 20:22;
L.sums = 23:25; L.counts = 26:28;
L.dc = 29:155; L.raw = 156:160; L.raw_valid = 161:165;
L.level_ring = 166:197;
L.pending_keep = 198:201; L.pending_must = 202:205;
L.pending_mid = 206:209; L.anchors = 210:241;
L.candidates = 242:245; L.essential = 246:249;
L.size = 249;
end


function s = pam3_initial_state(cfg)
L = pam3_layout();
s = zeros(L.size, 1);
s(L.next) = cfg.initial_phase;
s(L.thresholds) = [cfg.plus; cfg.minus; cfg.zero_plus; cfg.zero_minus];
s(L.means) = [60; 127; 194] * 256;
end


function [s, y] = pam3_step(s, adc, command, cfg)
% One discrete sample position; pure transition, no persistent receiver state.
% command: 0=idle, 1=real ADC, 2=tail flush, 3=reset.
% y: [symbol_valid symbol index corrected raw raw_valid filtered
%     filtered_valid filtered_index plus minus zplus zminus edge must
%     candidate essential capture_end]'. All indices are zero-based.
persistent L
if isempty(L)
    L = pam3_layout();
end
y = zeros(18, 1);
y(3) = -1; y(9) = -1;
y(10:13) = s(L.thresholds);
if command == 3
    s = pam3_initial_state(cfg);
    y(10:13) = s(L.thresholds);
    return;
end
if command == 0
    return;
end
assert(command == 1 || command == 2, 'PAM3:Command', 'Invalid command.');
assert(s(L.tick) < flintmax - 64, 'PAM3:Index', 'Reset before index precision is lost.');
real_sample = command == 1;
if real_sample
    assert(s(L.ending) == 0, 'PAM3:Capture', 'Reset before a new capture.');
    assert(isfinite(adc) && adc >= 0 && adc <= 255 && adc == floor(adc), ...
        'PAM3:ADC', 'ADC input must be an integer code in 0..255.');
else
    if s(L.ending) == 0
        s(L.ending) = 1;
        s(L.length) = s(L.tick);
    end
    if s(L.flush_count) >= 20
        return;
    end
    s(L.flush_count) = s(L.flush_count) + 1;
end
t = s(L.tick);
thresholds = s(L.thresholds);
y(10:13) = thresholds;
if real_sample
    corrected = adc;
    if cfg.dc_enabled
        values = [adc; s(L.dc(1:s(L.dc_filled)))];
        lo = min(values); hi = max(values);
        candidate = adc - lo + cfg.dc_anchor;
        if hi > thresholds(1) && lo < cfg.dc_min_gate && candidate < 255
            corrected = candidate;
        end
    end
    if s(L.initialized)
        if corrected > s(L.previous)
            if corrected > thresholds(1)
                s(L.level) = 1;
            elseif corrected < thresholds(1) && corrected > thresholds(4)
                s(L.level) = 0;
            end
        elseif corrected < s(L.previous)
            if corrected < thresholds(2)
                s(L.level) = -1;
            elseif corrected > thresholds(2) && corrected < thresholds(3)
                s(L.level) = 0;
            end
        end
    end
    s(L.previous) = corrected; s(L.initialized) = 1;
    y(4:6) = [corrected; s(L.level); 1];
    if cfg.dc_enabled
        s(L.dc) = [adc; s(L.dc(1:end-1))];
        s(L.dc_filled) = min(127, s(L.dc_filled) + 1);
    end
    if cfg.adaptive_mode ~= 0
        k = s(L.level) + 2;
        s(L.sums(k)) = s(L.sums(k)) + corrected;
        s(L.counts(k)) = s(L.counts(k)) + 1;
        s(L.block_count) = s(L.block_count) + 1;
        if s(L.block_count) == 12
            means = s(L.means);
            for j = 1:3
                if s(L.counts(j)) >= 3
                    avg = s(L.sums(j)) * 256 / s(L.counts(j));
                    if cfg.adaptive_mode == 1
                        avg = floor(avg);
                        means(j) = means(j) + floor((avg - means(j)) / 8);
                    else
                        means(j) = means(j) + (avg - means(j)) / 8;
                    end
                end
            end
            gl = means(2) - means(1); gh = means(3) - means(2);
            if gl >= 12 * 256 && gh >= 12 * 256
                ratios = [gh * 13 / 67; gl * 32 / 67; gh * 33 / 67; gl * 47 / 67];
                if cfg.adaptive_mode == 1
                    ratios = floor(ratios);
                end
                q8 = means(2) + ratios .* [1; -1; 1; -1];
                if cfg.adaptive_mode == 1
                    thresholds = floor((q8 + 128) / 256);
                else
                    thresholds = pam3_round_even(q8 / 256);
                end
                s(L.thresholds) = min(254, max(1, thresholds));
            end
            s(L.means) = means; s(L.block_count) = 0;
            s(L.sums) = 0; s(L.counts) = 0;
        end
    end
end

% Spike filter: use five ORIGINAL raw neighbours, with two-position lookahead.
s(L.raw) = [s(L.level); s(L.raw(1:end-1))];
s(L.raw_valid) = [double(real_sample); s(L.raw_valid(1:end-1))];
raw = s(L.raw); valid = s(L.raw_valid);
edge_now = false; must_now = false; keep_now = false; midpoint = 0;
if t >= 2 && valid(3)
    value = raw(3); fi = t - 2;
    if valid(4) && raw(3) ~= raw(4)
        if valid(2) && raw(2) ~= raw(3) && raw(4) == raw(2)
            value = raw(4);
        elseif valid(2) && valid(1) && raw(2) == raw(3) && ...
                raw(1) ~= raw(3) && raw(4) == raw(1)
            value = raw(4);
        end
    elseif valid(5) && valid(4) && valid(2) && raw(3) == raw(4) && ...
            raw(4) ~= raw(5) && raw(2) ~= raw(3) && raw(5) == raw(2)
        value = raw(5);
    end
    s(L.level_ring(mod(fi, 32) + 1)) = value;
    y(7:9) = [value; 1; fi];
    if s(L.filter_initialized) && value ~= s(L.previous_filtered)
        edge_now = true;
        direction = value > s(L.previous_filtered);
        distance = fi - s(L.last_edge);
        must_now = s(L.edge_initialized) && direction ~= s(L.direction) && distance <= 12;
        if must_now
            midpoint = s(L.last_edge) + floor((distance - 1) / 2);
        end
        keep_now = must_now || ~s(L.edge_initialized) || distance >= 9;
        s(L.edge_initialized) = 1; s(L.last_edge) = fi;
        s(L.direction) = double(direction);
    end
    s(L.filter_initialized) = 1; s(L.previous_filtered) = value;
end
y(14:15) = [double(edge_now); double(must_now)];
% Second edge filter waits four later filtered sample positions.
pk = s(L.pending_keep); pm = s(L.pending_must); pending_mid = s(L.pending_mid);
if pk(4) && pm(4) && ~must_now
    s(L.anchors(mod(pending_mid(4), 32) + 1)) = 1;
end
s(L.pending_keep) = [double(edge_now && keep_now); pk(1:3) .* double(~must_now)];
s(L.pending_must) = [double(must_now); pm(1:3)];
s(L.pending_mid) = [midpoint; pending_mid(1:3)];

% Delayed chronological candidate scanner: fixed clock plus retained anchors.
candidate_now = false; essential_now = false;
if t >= 16
    q = t - 16; ai = mod(q, 32) + 1;
    if ~s(L.ending) || q < s(L.length)
        essential_now = s(L.anchors(ai)) ~= 0;
        candidate_now = essential_now || q == s(L.next);
        if candidate_now
            s(L.next) = q + 12;
        end
    end
    s(L.anchors(ai)) = 0;
end
cb = s(L.candidates); eb = s(L.essential);
if t >= 20
    q = t - 20;
    if cb(4) && (eb(4) || ~(candidate_now || any(cb(1:3))))
        y(1:3) = [1; s(L.level_ring(mod(q, 32) + 1)); q];
    end
end
s(L.candidates) = [double(candidate_now); cb(1:3)];
s(L.essential) = [double(essential_now); eb(1:3)];
y(16:17) = [double(candidate_now); double(essential_now)];
y(18) = double(s(L.ending) && s(L.flush_count) == 20);
s(L.tick) = t + 1;
end

function r = pam3_round_even(x)
% Match NumPy's nearest-even rule, instead of MATLAB's ties-away rounding.
f = floor(x); a = x - f;
r = f + double(a > 0.5 | (a == 0.5 & mod(f, 2) ~= 0));
end

