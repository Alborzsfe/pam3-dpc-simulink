function c = dpc3_table_config(cfg,ts,channel_p,channel_q)
c.sample_time = ts; c.omega = 2*pi*cfg.line_frequency;
c.L = cfg.filter_inductance; c.R = cfg.filter_resistance;
c.scale = [channel_p.outer,channel_q.outer];
c.weights = cfg.power_weights;
c.prediction_guard = cfg.prediction_guard;
end
