"""Exploratory absence-aware ternary detector; no novelty or superiority claim.

The causal prediction of an unobserved high level is based on the affine
geometry learned from the same 16 labelled pilots used by every comparator.
Run: python research_stage8/initial_candidate.py
"""
from __future__ import annotations

import csv
import json
import sys
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "research_stage4"))
from reproduce import selective_store  # noqa: E402
from stage6_equal_budget_blind import (  # noqa: E402
    PILOT_COUNTS, detector, make_case, metrics,
)

CASES = (
    "stationary", "gain_up_1p5", "gain_down_0p75", "offset_up_0p35",
    "unequal_mid_0p65", "no_high_gain_up_1p5", "noise_up_0p32",
    "gain_up_1p25", "gain_down_0p85", "offset_down_0p3",
    "unequal_mid_1p25", "no_high_gain_up_1p25",
)
METHODS = ("song_kam", "v2", "v3", "candidate", "regime_router")


def candidate(samples: np.ndarray, pilots: np.ndarray, *, trace=False):
    """Predict high from the two tracked lower levels; do not learn from
    tentative highs. Separate high innovation is permitted only near the
    geometrically predicted high center. Always decide using past state.

    This is an engineering hypothesis, not a unique ML contribution. It
    assumes fixed relative level geometry after calibration.
    """
    c = np.array([pilots[:5].mean(), pilots[5:10].mean(), pilots[10:].mean()])
    q = (c[2] - c[1]) / (c[1] - c[0])
    out = np.empty(samples.size, dtype=np.uint8)
    trace_rows = []
    route = np.empty(samples.size, dtype=bool)
    c_initial = c.copy()
    high_age = 0
    for k, raw in enumerate(samples):
        x = float(raw)
        gap = c[1] - c[0]
        predicted = c[1] + q * gap
        # Two hypotheses: old directly observed high and current affine high.
        # After a drought, prior observations become less relevant.
        w = np.exp(-high_age / 96.0)
        high = w * c[2] + (1 - w) * predicted
        t1, t2 = (c[0] + c[1]) / 2, (c[1] + high) / 2
        decision = 0 if x < t1 else 1 if x < t2 else 2
        out[k] = decision
        # A pilot-calibrated geometric mismatch or low-level drift suggests
        # that the zero-anchored, equally spaced reference is misspecified.
        # With a missing high, a shift of the middle but not the low level
        # suggests a gain change whose upper threshold needs prediction.
        asymmetry = abs(q - 1.0) > .2
        offset_evidence = abs(c[0] - c_initial[0]) > .14
        drought_gain_evidence = high_age > 96 and abs(c[1]-c_initial[1]) > .14
        route[k] = asymmetry or offset_evidence or drought_gain_evidence
        if trace and k % 64 == 0:
            trace_rows.append((k, x, float(c[0]), float(c[1]), float(c[2]),
                               float(predicted), float(t1), float(t2), high_age))
        high_age += 1
        # The low and middle levels need to track an offset or gain change.
        # Nearest-center guarded updates resist obvious label contamination.
        if decision == 0 and abs(x-c[0]) < .46*max(gap, 1e-6):
            c[0] += .025*(x-c[0])
        elif decision == 1 and abs(x-c[1]) < .46*max(gap, 1e-6):
            c[1] += .025*(x-c[1])
        elif decision == 2 and gap > 0 and q > 0:
            if abs(x-predicted) < .37*q*gap:
                c[2] += .025*(x-c[2])
                high_age = 0
    return (out, trace_rows, route) if trace else (out, route)


def run(outdir: Path, seeds=8, length=12000, seed_base=839271):
    outdir.mkdir(parents=True, exist_ok=True)
    rows = []
    for case in CASES:
        for i in range(seeds):
            seed = seed_base + i * 1009 + CASES.index(case) * 100003
            rng = np.random.default_rng(seed)
            truth = rng.integers(0, 3, size=length, dtype=np.uint8)
            truth, levels, gain, offset, sigma = make_case(case, truth, rng)
            pilot_labels = np.repeat(np.arange(3), PILOT_COUNTS)
            pilots = levels[pilot_labels] + rng.normal(0, .18, size=len(pilot_labels))
            samples = offset + gain * levels[truth] + rng.normal(0, sigma)
            if case == "stationary" and i == 0:
                # One common, exact waveform for the prospective Proteus replay.
                with (outdir / "proteus_replay.csv").open("w", newline="") as h:
                    wr = csv.writer(h)
                    wr.writerow(["index", "time_s", "voltage_V", "true_level_for_scoring_only"])
                    for k in range(256):
                        wr.writerow([k, f"{(k+0.5)*1e-6:.9g}", f"{samples[k]:.9g}", int(truth[k])])
                np.savetxt(outdir / "proteus_pilots.csv", np.column_stack((pilot_labels, pilots)),
                           delimiter=",", header="known_level,measured_voltage_V", comments="")
                # Proteus analogue File Generator can ingest a two-column
                # time/voltage text waveform. Values are held between ticks;
                # the symbol center occurs at (k+.5)*Ts. Confirm import
                # mapping and the generator interpolation in the installed UI.
                replay = np.concatenate((pilots, samples[:256]))
                ts = 1e-6  # deliberately slowed simulation clock, not 10 Gb/s
                with (outdir / "proteus_waveform_pwl.txt").open("w") as h:
                    for j, voltage in enumerate(replay):
                        h.write(f"{j*ts:.9g} {voltage:.9g}\n")
                        h.write(f"{(j+1)*ts-1e-9:.9g} {voltage:.9g}\n")
            candidate_output, candidate_route = candidate(samples, pilots)
            pred = {
                "song_kam": selective_store(samples, pilots[10:], 3)[0],
                "v2": detector(samples, np.array([pilots[:5].mean(), pilots[5:10].mean(), pilots[10:].mean()]), age_prediction=False),
                "v3": detector(samples, np.array([pilots[:5].mean(), pilots[5:10].mean(), pilots[10:].mean()]), age_prediction=True),
                "candidate": candidate_output,
            }
            pred["regime_router"] = np.where(candidate_route, candidate_output, pred["song_kam"])
            if case == "stationary" and i == 0:
                with (outdir / "proteus_expected.csv").open("w", newline="") as h:
                    wr = csv.writer(h)
                    wr.writerow(["data_index", "truth_for_scoring_only", *METHODS])
                    for k in range(256):
                        wr.writerow([k, int(truth[k]), *[int(pred[m][k]) for m in METHODS]])
            if case == "no_high_gain_up_1p5" and i == 0:
                _, trace_rows, _ = candidate(samples, pilots, trace=True)
                with (outdir / "candidate_threshold_trace.csv").open("w", newline="") as h:
                    wr = csv.writer(h)
                    wr.writerow(["index", "received_V", "c0", "c1", "last_observed_c2", "predicted_c2", "T1", "T2", "age_high"])
                    wr.writerows(trace_rows)
            for method, decision in pred.items():
                measure = metrics(truth, decision, length // 2)
                rows.append({"case": case, "seed": seed, "method": method, **measure})
    keys = list(rows[0])
    with (outdir / "per_seed.csv").open("w", newline="") as h:
        wr = csv.DictWriter(h, fieldnames=keys)
        wr.writeheader()
        wr.writerows(rows)
    summary = []
    for case in CASES:
        for method in METHODS:
            group = [r for r in rows if r["case"] == case and r["method"] == method]
            summary.append({"case": case, "method": method,
                            **{key: float(np.mean([r[key] for r in group]))
                               for key in ("overall_ser", "post_ser", "early_ser", "late_ser", "false_transition_rate")}})
    with (outdir / "summary.csv").open("w", newline="") as h:
        wr = csv.DictWriter(h, fieldnames=list(summary[0]))
        wr.writeheader()
        wr.writerows(summary)
    (outdir / "metadata.json").write_text(json.dumps({"seeds": seeds, "length": length,
        "seed_base": seed_base, "pilots": list(PILOT_COUNTS), "noise_sigma": .18,
        "assumption": "fixed affine geometry; synthetic additive Gaussian noise",
        "candidate_constants": {"age_time": 96, "alpha": .025, "low_mid_guard": .46,
                                "high_guard": .37, "asymmetry_cutoff": .2,
                                "low_drift_cutoff": .14, "drought_age": 96,
                                "middle_drift_cutoff": .14}}, indent=2))
    return summary


if __name__ == "__main__":
    import argparse
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, default=Path(__file__).parent / "results")
    p.add_argument("--seeds", type=int, default=8)
    p.add_argument("--length", type=int, default=12000)
    p.add_argument("--seed-base", type=int, default=839271)
    args = p.parse_args()
    result = run(args.output, args.seeds, args.length, args.seed_base)
    for row in result:
        print(row["case"], row["method"], f'{row["post_ser"]:.5f}', f'{row["early_ser"]:.5f}')
