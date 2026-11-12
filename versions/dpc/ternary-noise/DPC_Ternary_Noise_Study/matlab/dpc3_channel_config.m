function c = dpc3_channel_config(cfg,ts,on_value,off_value,zero_enabled)
assert(isfinite(on_value) && isfinite(off_value) && on_value > off_value);
c.sample_time = ts; c.center = (on_value+off_value)/2;
c.outer = (on_value-off_value)/2;
c.inner = cfg.release_ratio*c.outer;
c.zero_enabled = logical(zero_enabled);
end
