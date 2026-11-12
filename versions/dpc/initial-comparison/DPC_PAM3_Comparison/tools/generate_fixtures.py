"""Independent offline fixtures for the power-error comparison.

Synthetic data are educational tests, never converter measurements.
The patent reference uses the unchanged independent Python decoder.
"""
from pathlib import Path
import sys, json, hashlib
import numpy as np
from scipy.io import savemat

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from python_reference.model import DecoderConfig, decode
from python_reference.integer_model import decode_integer


def relay(x, on, off, on_out=1, off_out=0):
    # Locate trigger events, then forward-fill. Independent of MATLAB loop.
    x = np.asarray(x)
    events = np.flatnonzero((x > on) | (x < off))
    output = np.full(len(x), off_out, dtype=float)
    for j, start in enumerate(events):
        stop = events[j+1] if j+1 < len(events) else len(x)
        output[start:stop] = on_out if x[start] > on else off_out
    return output


def ternary(x, on=1, off=-1, ratio=0.5):
    # Explicit three-state transition oracle, independent of two-relay design.
    center, h = (on+off)/2, (on-off)/2
    r = ratio*h
    state, output = 0, []
    for value in np.asarray(x)-center:
        if value > h: state = 1
        elif value < -h: state = -1
        elif state == 1 and value < r: state = 0
        elif state == -1 and value > -r: state = 0
        output.append(state)
    return np.asarray(output, dtype=float)


def expected(x, mode, on=1, off=-1, ratio=0.5):
    gain = 45/(on-off)
    offset = 95-gain*off
    adc = np.clip(np.floor(offset+gain*x+0.5), 0, 255).astype(np.uint8)
    cfg = DecoderConfig(adaptive=bool(mode), dc_enabled=False)
    patent = decode_integer(adc, cfg) if mode else decode(adc, cfg)
    return dict(binary=relay(x, on, off), ternary=ternary(x, on, off, ratio),
                adc=adc.astype(float), raw=patent['raw_levels'].astype(float),
                levels=patent['levels'].astype(float), points=patent['points'].astype(float),
                symbols=patent['symbols'].astype(float), thresholds=patent['thresholds'].astype(float))


def main():
    rng = np.random.default_rng(20261014)
    tests = [
        ('constant_zero', np.zeros(96)),
        ('constant_positive', np.full(96, 3.0)),
        ('constant_negative', np.full(96, -3.0)),
        ('exact_boundaries', np.tile([0, 1, 1.0001, 1, .5, .4999, 0, -1, -1.0001, -.5, -.4999], 7)),
        ('plateau_return', np.repeat([0, 2, .8, .5, .4, 0, -2, -.8, -.5, -.4, 0], 18)),
        ('clipping', np.repeat([0, 100, 0, -100, 0, 5, 0, -5], 20)),
    ]
    for width in [1, 2, 3, 8, 20]:
        tests.append((f'pulse_width_{width}', np.r_[np.zeros(25), np.full(width, 2), np.zeros(30),
                                                     np.full(width, -2), np.zeros(25)]))
    for j in range(9):
        clean = np.repeat(rng.choice([-2., 0., 2.], 40), 12)
        tests.append((f'noisy_{j}', clean+rng.normal(0, 0.04+0.06*j, len(clean))))
    cases = []
    for mode in [0, 1]:
        for name, x in tests:
            cases.append(dict(name=name, mode=mode, error=x, on=1., off=-1., ratio=.5,
                              **expected(x, mode)))
        x = np.repeat([0, 2.5, 1, -.2, -2, .4], 12)
        cases.append(dict(name='asymmetric_band', mode=mode, error=x, on=2., off=-1., ratio=.4,
                          **expected(x, mode, on=2., off=-1., ratio=.4)))
    # 0..20 ms with distinct plateaux, boundary noise, and brief excursions.
    ts = 5e-6
    t = np.arange(4001)*ts
    ep = np.zeros(len(t)); eq = np.zeros(len(t))
    for a, b, value in [(0,.002,0),(.002,.005,2.5),(.005,.007,.3),(.007,.010,-2.2),
                        (.010,.012,-.3),(.012,.015,0),(.015,.018,1.2),(.018,.021,0)]:
        ep[(t >= a) & (t < b)] = value
    for a, b, value in [(0,.003,0),(.003,.006,-2),(.006,.009,0),(.009,.012,2),
                        (.012,.014,0),(.014,.017,-1.2),(.017,.021,0)]:
        eq[(t >= a) & (t < b)] = value
    ep += rng.normal(0, .11, len(t)); eq += rng.normal(0, .09, len(t))
    # Isolated spikes during a neutral plateau, distinguish from real events.
    for k, width, amplitude in [(2510,1,2.2),(2600,2,-2.2),(2720,3,2.2),(2850,8,-2.2)]:
        ep[k:k+width] = amplitude
    demo = dict(time=t, errors=np.c_[ep,eq], sample_time=ts,
                kind='synthetic_educational', converter_executed=False,
                source_model='deterministic educational waveform; no converter run')
    cells = np.empty((1,len(cases)), dtype=object)
    for j, case in enumerate(cases): cells[0,j] = case
    file = ROOT/'data/comparison_fixtures.mat'
    savemat(file, dict(cases=cells, demo=demo), do_compression=True, oned_as='column')
    manifest = dict(seed=20261014, cases=len(cases), error_samples=sum(len(c['error']) for c in cases),
                    patent_modes=[0,1], demo_samples_per_channel=len(t),
                    source='Independent Python event/three-state oracles + previous offline patent reference',
                    converter_executed=False, file_sha256=hashlib.sha256(file.read_bytes()).hexdigest())
    (ROOT/'validation/fixture_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(json.dumps(manifest,indent=2))


if __name__ == '__main__': main()
