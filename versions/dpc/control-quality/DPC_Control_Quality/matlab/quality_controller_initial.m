function s = quality_controller_initial(cfg)
if strcmp(cfg.variant, 'patent_filtered_hold')
    s = [pam3_initial_state(cfg.patent); cfg.off_output];
else
    s = zeros(7, 1); s(7) = cfg.off_output;
end
end
