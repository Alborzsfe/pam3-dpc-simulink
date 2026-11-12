function dpc_validate_config(cfg)
assert(isscalar(cfg.sample_time) && isfinite(cfg.sample_time) && cfg.sample_time > 0);
assert(isscalar(cfg.release_ratio) && cfg.release_ratio > 0 && cfg.release_ratio < 1);
assert(isscalar(cfg.analysis_start) && isfinite(cfg.analysis_start) && cfg.analysis_start >= 0);
assert(any(cfg.patent_mode == [0, 1]));
assert(any(strcmp(cfg.plot_visible, {'on', 'off'})));
for name = {'relay_on', 'relay_off', 'relay_output_on', 'relay_output_off'}
    value = cfg.(name{1});
    assert(numel(value) == 2 && all(isfinite(value)));
end
assert(all(cfg.relay_on > cfg.relay_off));
assert(all(cfg.relay_output_on ~= cfg.relay_output_off));
end
