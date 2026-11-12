function [s, decision, debug] = quality_controller_step(s, error_value, cfg)
% Causal proposed controller. +/-1 updates DPC binary state; 0 holds it.
assert(isscalar(error_value) && isfinite(error_value));
if strcmp(cfg.variant, 'patent_filtered_hold')
    adc_unclipped = cfg.adc_offset+cfg.adc_gain*error_value;
    adc = min(255, max(0, floor(adc_unclipped+0.5)));
    [receiver, y] = pam3_step(s(1:end-1), adc, 1, cfg.patent);
    decision = s(end);
    if y(8) ~= 0
        if y(7) > 0, decision = cfg.on_output; end
        if y(7) < 0, decision = cfg.off_output; end
    end
    s = [receiver; decision];
    debug = [y(5); y(7); y(8); double(adc_unclipped < 0 || adc_unclipped > 255)];
else
    % A separate engineering alternative: direct error-band classification.
    level = double(error_value > cfg.on_value)-double(error_value < cfg.off_value);
    raw = [level; s(1:4)]; count = min(5, s(6)+1);
    filtered = 0; valid = count >= 3;
    if valid
        filtered = raw(3);
        if count >= 4 && raw(3) ~= raw(4)
            if raw(2) ~= raw(3) && raw(4) == raw(2)
                filtered = raw(4);
            elseif raw(2) == raw(3) && raw(1) ~= raw(3) && raw(4) == raw(1)
                filtered = raw(4);
            end
        elseif count >= 5 && raw(3) == raw(4) && raw(4) ~= raw(5) && ...
                raw(2) ~= raw(3) && raw(5) == raw(2)
            filtered = raw(5);
        end
    end
    decision = s(7);
    if valid
        if filtered > 0, decision = cfg.on_output; end
        if filtered < 0, decision = cfg.off_output; end
    end
    s = [raw; count; decision];
    debug = [level; filtered; double(valid); 0];
end
end
