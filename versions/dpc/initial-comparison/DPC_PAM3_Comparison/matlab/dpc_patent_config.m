function patent_cfg = dpc_patent_config(cfg)
patent_cfg = pam3_config();
patent_cfg.sample_time = cfg.sample_time;
patent_cfg.dc_enabled = false;
patent_cfg.adaptive_mode = cfg.patent_mode;
end
