function s = pam3_initial_state(cfg)
L = pam3_layout();
s = zeros(L.size, 1);
s(L.next) = cfg.initial_phase;
s(L.thresholds) = [cfg.plus; cfg.minus; cfg.zero_plus; cfg.zero_minus];
s(L.means) = [60; 127; 194] * 256;
end
