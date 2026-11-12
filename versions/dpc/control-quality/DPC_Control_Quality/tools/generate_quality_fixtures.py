"""Independent offline oracles. These signals are TEST DATA, not converter results."""
from pathlib import Path
import sys
import numpy as np
from scipy.io import savemat

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from python_reference.model import DecoderConfig, slope_decode, spike_filter

rng = np.random.default_rng(20261014)
inputs = [
    np.zeros(101), np.full(101, 5.), np.full(101, -5.),
    np.tile([-1., 1., 0., 0.5, -0.5, 0.], 40),
    np.repeat([-4., 0., 4., 0., -4.], [30, 30, 30, 30, 30]),
    np.r_[np.full(20, -4.), 4., np.full(20, -4.), [4.,4.], np.full(20,-4.),
          [4.,4.,4.], np.full(20,-4.)],
    np.repeat(rng.choice([-10.,-2.,0.,2.,10.], 300), rng.integers(1,25,300)),
    rng.normal(0, 3, 1500), np.linspace(-20,20,701),
    np.r_[np.zeros(20), [100.,-100.], np.zeros(20), np.full(30,3.)],
]
cases = []
for variant in ['patent_filtered_hold', 'ternary_spike_hold']:
    for fs in [20000., 200000.]:
        for errors in inputs:
            if variant == 'patent_filtered_hold':
                adc = np.clip(np.floor(117.5+22.5*errors+0.5), 0, 255).astype(int)
                raw, _ = slope_decode(adc, DecoderConfig())
            else:
                raw = (errors > 1).astype(int)-(errors < -1).astype(int)
            filtered = spike_filter(raw, 2)
            expected = np.zeros(len(errors))
            latch = 0
            for k in range(2, len(errors)):
                if filtered[k-2] > 0: latch = 1
                if filtered[k-2] < 0: latch = 0
                expected[k] = latch
            cases.append(dict(variant=variant, fs=fs, errors=errors[:,None], expected=expected[:,None]))
savemat(ROOT/'data'/'quality_fixtures.mat', {'cases': np.array(cases,dtype=object)[None,:]}, do_compression=True)
print(f'Generated {len(cases)} independent cases, {sum(len(c["errors"]) for c in cases)} samples.')
