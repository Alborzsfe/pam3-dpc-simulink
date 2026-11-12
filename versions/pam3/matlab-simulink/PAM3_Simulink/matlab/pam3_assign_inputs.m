function pam3_assign_inputs(adc_a, adc_b, cfg)
% Already-deserialized ADC boundary. Both channels share sample positions.
adc_a = double(adc_a(:)); adc_b = double(adc_b(:));
assert(numel(adc_a) == numel(adc_b), 'PAM3:Length', 'Paired input lengths differ.');
n = numel(adc_a); total = n + 20;
t = (0:total-1)' * cfg.sample_time;
a = [adc_a; zeros(20, 1)]; b = [adc_b; zeros(20, 1)];
command = [ones(n, 1); 2*ones(20, 1)];
assignin('base', 'pam3_cfg', cfg);
assignin('base', 'pam3_input_master', [t, a]);
assignin('base', 'pam3_input_slave', [t, b]);
assignin('base', 'pam3_command', [t, command]);
assignin('base', 'pam3_stop_time', t(end));
end
