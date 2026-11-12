function c = quality_controller_config(cfg, sample_time, on_value, off_value)
c.sample_time = sample_time;
c.on_value = on_value; c.off_value = off_value;
c.on_output = 1; c.off_output = 0;
c.variant = cfg.proposed_variant;
assert(on_value > off_value);
c.patent = pam3_config();
c.patent.sample_time = sample_time;
c.patent.dc_enabled = false; c.patent.adaptive_mode = 0;
c.adc_gain = 45/(on_value-off_value);
c.adc_offset = 95-c.adc_gain*off_value;
end
