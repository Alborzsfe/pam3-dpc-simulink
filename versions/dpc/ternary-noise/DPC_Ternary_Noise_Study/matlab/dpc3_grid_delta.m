function delta = dpc3_grid_delta(time,cfg,s)
% Physical additive voltage, balanced 5th/7th harmonic phase sequences.
time = time(:); phi = [0,-2*pi/3,2*pi/3];
theta = bsxfun(@plus,2*pi*cfg.line_frequency*time,phi);
wave = s.h5_pu*sin(5*theta)+s.h7_pu*sin(7*theta)+ ...
    bsxfun(@times,s.ripple_pu*sin(2*pi*s.ripple_hz*time),sin(theta));
delta = cfg.phase_rms_voltage*sqrt(2)*wave;
delta(time < cfg.disturbance_start,:) = 0;
end
