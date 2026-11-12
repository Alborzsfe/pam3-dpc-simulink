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
