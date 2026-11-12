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
