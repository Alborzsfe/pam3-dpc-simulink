from dataclasses import dataclass, asdict
import numpy as np
from scipy.signal import lfilter


@dataclass(frozen=True)
class ChannelConfig:
    n_symbols: int = 4096
    snr_db: float = 30.0
    gain: float = 1.0
    dc_offset: float = 0.0
    phase_samples: float = 1.7
    clock_ppm: float = 0.0
    jitter_rms_samples: float = 0.0
    rise_tau_samples: float = 0.8
    echo_fraction: float = 0.0
    echo_delay_samples: int = 6
    leakage_fraction: float = 0.0
    impulse_probability: float = 0.0
    impulse_amplitude: float = 70.0
    dc_step: float = 0.0
    gain_step: float = 0.0
    pattern: str = "random"
    seed: int = 11405248


def make_symbols(n, rng, pattern="random"):
    if pattern == "alternating":
        return np.resize(np.array([-1, 0, 1, 0],dtype=np.int8),n)
    if pattern == "two_levels":
        return rng.choice(np.array([-1,0],dtype=np.int8),n)
    if pattern == "long_runs":
        # 48 random symbols followed by 1024 zeros per repeated segment.
        x = rng.integers(-1,2,n,dtype=np.int8)
        for start in range(48,n,1072): x[start:min(start+1024,n)] = 0
        return x
    return rng.integers(-1,2,n,dtype=np.int8)


def generate_channel(cfg):
    """Behavioural coupler + DVGA + finite-bandwidth channel + 8-bit ADC model.

    Not an IEEE-compliant PCS encoder or a component SPICE model. Symbols are
    synthetic PAM-3, and clock_jitter is explicitly receiver-relative in samples.
    """
    rng = np.random.default_rng(cfg.seed)
    tx = make_symbols(cfg.n_symbols,rng,cfg.pattern)
    reverse = make_symbols(cfg.n_symbols,rng)
    period = 12.0*(1.0+cfg.clock_ppm*1e-6)
    boundaries = cfg.phase_samples + np.arange(cfg.n_symbols+1)*period
    if cfg.jitter_rms_samples:
        jit = rng.normal(0,cfg.jitter_rms_samples,cfg.n_symbols+1)
        # Restrict extremes so no symbol has negative duration.
        boundaries += np.clip(jit,-period*0.35,period*0.35)
    length = int(np.ceil(boundaries[-1])) + 24
    sample = np.arange(length,dtype=float)
    index = np.clip(np.searchsorted(boundaries,sample,side="right")-1,0,cfg.n_symbols-1)
    clean = tx[index].astype(float)
    reverse_index = np.clip(np.searchsorted(boundaries,sample+3.1,side="right")-1,0,cfg.n_symbols-1)
    reverse_wave = reverse[reverse_index].astype(float)
    def bandwidth(x):
        if cfg.rise_tau_samples<=0: return x.copy()
        a = np.exp(-1.0/cfg.rise_tau_samples)
        return lfilter([1-a],[1,-a],x,zi=[a*x[0]])[0]
    signal = bandwidth(clean)
    reverse_wave = bandwidth(reverse_wave)
    if cfg.echo_fraction:
        delayed = np.pad(signal,(cfg.echo_delay_samples,0),mode="edge")[:length]
        signal = (signal+cfg.echo_fraction*delayed)/(1+abs(cfg.echo_fraction))
    gain = np.full(length,cfg.gain,dtype=float)
    offset = np.full(length,cfg.dc_offset,dtype=float)
    gain[length//2:] += cfg.gain_step
    offset[length//2:] += cfg.dc_step
    ideal = 127.0 + 67.0*gain*signal + 67.0*cfg.leakage_fraction*reverse_wave + offset
    # SNR relative to nominal transmitted zero-mean symbol power: 67^2 * E[s^2].
    power = 67.0**2*float(np.mean(tx.astype(float)**2))
    sigma = np.sqrt(power/10**(cfg.snr_db/10)) if np.isfinite(cfg.snr_db) else 0.0
    noise = rng.normal(0,sigma,length)
    impulses = rng.random(length)<cfg.impulse_probability
    noise[impulses] += rng.choice([-1,1],int(np.sum(impulses)))*cfg.impulse_amplitude
    analog_code = ideal+noise
    adc = np.clip(np.rint(analog_code),0,255).astype(np.uint8)
    return dict(adc=adc,tx=tx,reverse_tx=reverse,boundaries=boundaries,
                centers=(boundaries[:-1]+boundaries[1:])/2,
                expected_levels=tx[index],ideal=ideal,noise_sigma=sigma,
                clipping_fraction=float(np.mean((analog_code<0)|(analog_code>255))),
                config=asdict(cfg))


def evaluate(signal, decoded, warmup_symbols=32):
    """TX clock is used ONLY here, never by decoder. All missing/extra counted.

    Group receiver samples by true TX interval. A symbol passes only with exactly
    one receiver output in its interval AND a correct value. No dynamic sequence
    alignment or phase chosen using labels. Last 8 symbols excluded for flush.
    """
    points = np.asarray(decoded["points"],dtype=int)
    values = np.asarray(decoded["symbols"],dtype=int)
    bounds, tx = signal["boundaries"],signal["tx"]
    mapped = np.searchsorted(bounds,points,side="right")-1
    lo, hi = warmup_symbols,len(tx)-8
    valid = (mapped>=lo)&(mapped<hi)
    mapped, points, values = mapped[valid],points[valid],values[valid]
    counts = np.bincount(mapped,minlength=len(tx))
    single = counts==1
    right = np.zeros(len(tx),dtype=bool)
    right[mapped] = (values==tx[mapped]) & single[mapped]
    correct = int(right[lo:hi].sum())
    n = hi-lo
    missing = int((counts[lo:hi]==0).sum())
    duplicated = int((counts[lo:hi]>1).sum())
    extras = int(np.maximum(counts[lo:hi]-1,0).sum())
    amplitude_errors = int(np.sum(single[mapped]&(values!=tx[mapped])))
    timing = (points-signal["centers"][mapped])/np.diff(bounds)[mapped]
    raw_wrong = int(np.sum(values!=tx[mapped]))
    errors = n-correct
    rate = errors/n
    z = 1.959963984540054
    denominator = 1+z*z/n
    center = (rate+z*z/(2*n))/denominator
    half = z*np.sqrt(rate*(1-rate)/n+z*z/(4*n*n))/denominator
    return dict(n_evaluated=n,correct=correct,errors=errors,ser_total=rate,
                missing=missing,duplicated_symbols=duplicated,extra_outputs=extras,
                amplitude_errors_single=amplitude_errors,output_value_errors=raw_wrong,
                output_count=len(points),ser_wilson_low=max(0,center-half),
                ser_wilson_high=min(1,center+half),
                timing_rms_ui=float(np.sqrt(np.mean(timing**2))) if len(timing) else None,
                timing_p95_abs_ui=float(np.quantile(abs(timing),0.95)) if len(timing) else None,
                clipping_fraction=signal["clipping_fraction"],
                warmup_symbols=warmup_symbols,tail_excluded_symbols=8)
