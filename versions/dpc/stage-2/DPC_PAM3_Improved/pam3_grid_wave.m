function v=pam3_grid_wave(t,e,f,thd)
% Continuous three-phase source waveform. Equal 5th/7th RMS contributions.
% h*phase gives negative-sequence fifth and positive-sequence seventh.
phase=[0;-2*pi/3;2*pi/3];theta=2*pi*f*t+phase;
v=e*sqrt(2)*(sin(theta)+(thd/sqrt(2))*(sin(5*theta)+sin(7*theta)));
end
