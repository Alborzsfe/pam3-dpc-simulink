function pam3_validate_config(cfg)
assert(isscalar(cfg.sample_time) && isfinite(cfg.sample_time) && cfg.sample_time > 0);
assert(any(cfg.adaptive_mode == [0, 1, 2]));
assert(~(cfg.dc_enabled && cfg.adaptive_mode == 2), ...
    'PAM3:FloatDC', 'Use Q8 mode for combined DC and adaptation.');
assert(cfg.initial_phase >= 0 && cfg.initial_phase <= 11 && ...
    cfg.initial_phase == floor(cfg.initial_phase));
values = [cfg.plus, cfg.minus, cfg.zero_plus, cfg.zero_minus, cfg.dc_min_gate, cfg.dc_anchor];
assert(all(isfinite(values)) && all(values >= 0) && all(values <= 255));
assert(all(values == floor(values)));
end
