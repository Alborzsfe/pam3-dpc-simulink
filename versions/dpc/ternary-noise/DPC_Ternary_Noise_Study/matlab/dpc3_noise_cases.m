function cases = dpc3_noise_cases()
base = struct('id','normal','label','Ideal grid / no added noise', ...
    'voltage_noise_rms_pu',0,'power_noise_rms',[0,0], ...
    'h5_pu',0,'h7_pu',0,'ripple_pu',0,'ripple_hz',300);
cases = repmat(base,1,7);
cases(2).id = 'vnoise_1pct'; cases(2).label = 'Voltage sensor noise: 1% RMS';
cases(2).voltage_noise_rms_pu = 0.01;
cases(3).id = 'vnoise_3pct'; cases(3).label = 'Voltage sensor noise: 3% RMS';
cases(3).voltage_noise_rms_pu = 0.03;
cases(4).id = 'pqnoise_05'; cases(4).label = 'Power feedback noise: 0.5 W / 0.5 var RMS';
cases(4).power_noise_rms = [0.5,0.5];
cases(5).id = 'pqnoise_2'; cases(5).label = 'Power feedback noise: 2 W / 2 var RMS';
cases(5).power_noise_rms = [2,2];
cases(6).id = 'grid_distorted'; cases(6).label = 'Physical grid: 5th 5%, 7th 3%, amplitude ripple 2%';
cases(6).h5_pu = 0.05; cases(6).h7_pu = 0.03; cases(6).ripple_pu = 0.02;
cases(7) = cases(6); cases(7).id = 'combined';
cases(7).label = 'Distorted grid + voltage sensor 1% + power feedback 2 W/var';
cases(7).voltage_noise_rms_pu = 0.01; cases(7).power_noise_rms = [2,2];
end
