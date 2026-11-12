function data = make_test_input(cfg)
% Coherent, integer-cycle signals. No signal-processing toolbox required.
spp = round(cfg.fs_hz / cfg.f0_hz);
assert(cfg.fs_hz > 0 && cfg.f0_hz > 0 && ...
    abs(cfg.fs_hz/cfg.f0_hz - spp) < 1e-10, ...
    'Compare:Coherence', 'fs/f0 must be an integer.');
cycles = [cfg.warmup_cycles, cfg.measure_cycles, cfg.tail_cycles];
assert(all(cycles >= 0 & cycles == floor(cycles)) && ...
    cfg.measure_cycles >= 1 && cfg.tail_cycles >= 1);
assert(cfg.amplitude > 0 && cfg.adc_gain > 0);
assert(cfg.max_harmonic >= 2 && cfg.max_harmonic == floor(cfg.max_harmonic));
assert(cfg.max_harmonic*cfg.f0_hz < cfg.fs_hz/2, ...
    'Compare:Nyquist', 'Selected harmonics must be strictly below Nyquist.');
assert(isfinite(cfg.noise_snr_db));
n = sum(cycles)*spp;
index = (cfg.warmup_cycles*spp+1):((cfg.warmup_cycles+cfg.measure_cycles)*spp);
% Tiling avoids tiny floating-point differences between nominally equal cycles.
one_cycle = cfg.amplitude*sin(2*pi*(0:spp-1)'/spp);
clean = repmat(one_cycle, sum(cycles), 1);
noise = portable_gaussian(n, cfg.seed);
noise = noise - mean(noise(index));
target_rms = sqrt(mean(clean(index).^2))*10^(-cfg.noise_snr_db/20);
noise = noise * (target_rms/sqrt(mean(noise(index).^2)));
analog = [clean, clean+noise];
unclipped = floor(cfg.adc_center + cfg.adc_gain*analog + 0.5);
adc = min(255, max(0, unclipped));
data = struct();
data.t = (0:n-1)'*(1/cfg.fs_hz);
data.clean = clean;
data.noise = noise;
data.analog = analog;
data.adc = adc;
data.normalized_adc = (adc-cfg.adc_center)/cfg.adc_gain;
data.measure_index = index(:);
data.samples_per_cycle = spp;
data.realized_snr_db = 10*log10(mean(clean(index).^2)/mean(noise(index).^2));
data.clipped_samples = sum(adc ~= unclipped, 1);
end

function x = portable_gaussian(n, seed)
% Park-Miller uniforms and Box-Muller normals, reproducible across engines.
assert(isscalar(seed) && seed == floor(seed) && seed >= 1 && seed < 2147483647);
state = double(seed);
x = zeros(n, 1);
for k = 1:2:n
    state = mod(16807*state, 2147483647);
    u1 = state/2147483647;
    state = mod(16807*state, 2147483647);
    u2 = state/2147483647;
    radius = sqrt(-2*log(u1));
    x(k) = radius*cos(2*pi*u2);
    if k+1 <= n
        x(k+1) = radius*sin(2*pi*u2);
    end
end
end
