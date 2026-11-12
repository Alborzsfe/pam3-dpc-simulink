function input = generate_pam3_input(options)
% Behavioural two-direction source, finite bandwidth, DVGA, noise and 8-bit ADC.
% This is synthetic PAM3, not an IEEE PCS encoder or component circuit model.
if nargin < 1
    options = struct();
end
defaults = struct('symbols', 512, 'snr_db', 30, 'seed', 11405248, ...
    'gain', [1, 1], 'dc_offset', [0, 0], 'phase_samples', [1.7, 2.8], ...
    'clock_ppm', 0, 'rise_tau_samples', 0.8, 'leakage', 0, ...
    'gain_step', [0, 0], 'dc_step', [0, 0]);
fields = fieldnames(defaults);
for k = 1:numel(fields)
    if ~isfield(options, fields{k})
        options.(fields{k}) = defaults.(fields{k});
    end
end
assert(options.symbols >= 1 && options.symbols == floor(options.symbols));
assert(options.clock_ppm > -1e6);
assert(numel(options.gain) == 2 && numel(options.dc_offset) == 2 && numel(options.phase_samples) == 2);
rng(options.seed, 'twister');
period = 12 * (1 + options.clock_ppm * 1e-6);
tx = {randi(3, options.symbols, 1)-2, randi(3, options.symbols, 1)-2};
bounds = {options.phase_samples(1)+(0:options.symbols)'*period, ...
          options.phase_samples(2)+(0:options.symbols)'*period};
n = ceil(max(bounds{1}(end), bounds{2}(end))) + 24;
t = (0:n-1)'; wave = zeros(n, 2);
for channel = 1:2
    [~, index] = histc(t, bounds{channel}); %#ok<HISTC>
    index = min(options.symbols, max(1, index));
    clean = tx{channel}(index);
    if options.rise_tau_samples > 0
        pole = exp(-1 / options.rise_tau_samples);
        clean = filter(1-pole, [1, -pole], clean, pole*clean(1));
    end
    wave(:, channel) = clean;
end
adc = zeros(n, 2);
for channel = 1:2
    gain = options.gain(channel) * ones(n, 1);
    offset = options.dc_offset(channel) * ones(n, 1);
    split = floor(n/2)+1;
    gain(split:end) = gain(split:end) + options.gain_step(channel);
    offset(split:end) = offset(split:end) + options.dc_step(channel);
    % Residual reverse-direction leakage after an idealized directional split.
    other = 3-channel;
    analog = 127 + 67*gain.*wave(:,channel) + 67*options.leakage*wave(:,other) + offset;
    power = 67^2 * mean(tx{channel}.^2);
    sigma = sqrt(power / 10^(options.snr_db/10));
    analog = analog + sigma*randn(n, 1);
    adc(:, channel) = min(255, max(0, round(analog)));
end
input = struct('adc_master', adc(:,1), 'adc_slave', adc(:,2), ...
    'tx_master', tx{1}, 'tx_slave', tx{2}, ...
    'boundaries_master', bounds{1}, 'boundaries_slave', bounds{2}, 'options', options);
end
