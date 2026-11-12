"""Independent ABC quadrature + exhaustive noisy-power table oracle (not Simulink)."""
from pathlib import Path
import numpy as np
from scipy.io import savemat
from reference_and_fixtures import predict, power_abc, operating_point, SOURCE_TABLE, GATES, LEGS

ROOT = Path(__file__).resolve().parents[1]


def oracle(sp, sq, sector, v, i, dc, ref, bits, previous, ts, measured):
    future, model_now = predict(v, i, dc, ts)
    # Anchor predicted increments to measured (possibly noisy) P/Q.
    future += (measured - model_now)[:, None]
    original = int(SOURCE_TABLE[*bits, sector - 1] @ [4, 2, 1])
    tracking = np.sum((future - ref[:, None]) ** 2, axis=0)
    table, guard = [], []
    for p in (-1, 0, 1):
        for q in (-1, 0, 1):
            guarded = 0
            if p and q:
                chosen = int(SOURCE_TABLE[(p + 1) // 2, (q + 1) // 2, sector - 1] @ [4, 2, 1])
            else:
                target = measured + [p, q] * np.maximum(abs(ref - measured), 1.)
                loss = np.sum((future - target[:, None]) ** 2, axis=0)
                candidates = np.flatnonzero(loss <= min(loss) + 1e-12 * max(1., abs(min(loss))))
                chosen = min(candidates, key=lambda j: (np.count_nonzero(LEGS[j] != previous), j))
                if tracking[chosen] > tracking[original] + 1e-12 * max(1., tracking[original]):
                    chosen, guarded = original, 1
            table.append(chosen)
            guard.append(guarded)
    row = 3 * (sp + 1) + sq + 1
    chosen = table[row]
    audit = np.r_[sp, sq, sector, row + 1, chosen, measured,
                  future[:, chosen] - measured, tracking[chosen], tracking[original], guard[row], table]
    return GATES[chosen], audit


def main():
    rng = np.random.default_rng(20261015)
    inputs, gates, audits, native = [], [], [], []
    for fs in (20000., 200000.):
        for sector in range(1, 13):
            for sigma in (0., .5, 4.):
                for sp in (-1, 0, 1):
                    for sq in (-1, 0, 1):
                        v, i, dc = operating_point(sector, 350., 15.)
                        v += rng.normal(0., sigma, 3)
                        measured = power_abc(v, i) + rng.normal(0., 2 * sigma, 2)
                        ref = measured + np.array([sp, sq]) * 15
                        bits = rng.integers(0, 2, 2)
                        previous = rng.integers(0, 2, 3)
                        g, a = oracle(sp, sq, sector, v, i, dc, ref, bits, previous, 1/fs, measured)
                        inputs.append(np.r_[sp, sq, sector, v, i, dc, ref, bits, previous, 1/fs, .2, measured])
                        gates.append(g)
                        audits.append(a)
        matrix, ng, na, previous = [], [], [], np.zeros(3)
        for sector in range(1, 13):
            for sp in (-1, 0, 1):
                for sq in (-1, 0, 1):
                    v, i, dc = operating_point(sector, 400., -20.)
                    v += rng.normal(0., 1., 3)
                    measured = power_abc(v, i) + rng.normal(0., 3., 2)
                    ref = measured + np.array([sp, sq]) * 8
                    bits = rng.integers(0, 2, 2)
                    g, a = oracle(sp, sq, sector, v, i, dc, ref, bits, previous, 1/fs, measured)
                    matrix.append(np.r_[sp, sq, sector, v, i, dc, ref, bits, measured])
                    ng.append(g)
                    na.append(a)
                    previous = g[[0, 2, 4]]
        native.append(dict(fs=fs, input=np.array(matrix), gates=np.array(ng), audit=np.array(na)))
    savemat(ROOT / 'data/dpc3_noise_golden.mat', dict(
        table_inputs=np.array(inputs), gates=np.array(gates), audit=np.array(audits),
        native=np.array(native, dtype=object)[None, :]), do_compression=True)
    print(f'Independent noisy-feedback fixtures: {len(inputs)} contexts, '
          f'{sum(len(x["input"]) for x in native)} native stream samples; not converter simulations.')


if __name__ == '__main__':
    main()
