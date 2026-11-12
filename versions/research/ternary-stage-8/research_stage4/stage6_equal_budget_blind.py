"""Stage 6: equal-startup-budget ternary stress tests and a blind bootstrap.

Two separate, within-protocol comparisons:
  labelled_16: all methods receive exactly 16 known pilots (5,5,6).
  blind_192: no pilots; all methods inspect the same first 192 unlabeled data
             samples, which are excluded from scoring.

The paper's decision rule is unchanged AFTER initialization. Its original
initialization is pilot based; the blind bootstrap is our explicit extension.
"""
from __future__ import annotations

import argparse
import csv
import json
import math
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np

from reproduce import selective_store


PILOT_COUNTS = (5, 5, 6)
BOOTSTRAP = 192
ALPHA = .015
METHODS = ("fixed", "song_kam", "v2_three_centers", "v3_age_affine", "oracle")
DEV = ("stationary", "gain_up_1p5", "gain_down_0p75", "offset_up_0p35",
       "unequal_mid_0p65", "no_high_gain_up_1p5", "noise_up_0p32")
VALID = ("gain_up_1p25", "gain_down_0p85", "offset_down_0p3",
         "unequal_mid_1p25", "no_high_gain_up_1p25", "bootstrap_no_high")


def make_case(case: str, truth: np.ndarray, rng: np.random.Generator):
    n = len(truth)
    levels = np.array([0.0, 1.0, 2.0])
    gain = np.ones(n)
    offset = np.zeros(n)
    sigma = np.full(n, .18)
    half = n // 2
    if case in ("gain_up_1p5", "no_high_gain_up_1p5"):
        gain[half:] = 1.5
    elif case in ("gain_up_1p25", "no_high_gain_up_1p25"):
        gain[half:] = 1.25
    elif case == "gain_down_0p75":
        gain[half:] = .75
    elif case == "gain_down_0p85":
        gain[half:] = .85
    elif case == "offset_up_0p35":
        offset[half:] = .35
    elif case == "offset_down_0p3":
        offset[half:] = -.3
    elif case == "unequal_mid_0p65":
        levels[1] = .65
    elif case == "unequal_mid_1p25":
        levels[1] = 1.25
    elif case == "noise_up_0p32":
        sigma[half:] = .32
    elif case not in ("stationary", "bootstrap_no_high"):
        raise ValueError(case)
    if case.startswith("no_high_gain"):
        begin, end = half - 1800, half + 1800
        segment = truth[begin:end]
        mask = segment == 2
        segment[mask] = rng.integers(0, 2, size=int(mask.sum()))
    if case == "bootstrap_no_high":
        mask = truth[:BOOTSTRAP] == 2
        truth[:BOOTSTRAP][mask] = rng.integers(0, 2, size=int(mask.sum()))
    return truth, levels, gain, offset, sigma


def blind_centers(values: np.ndarray) -> tuple[np.ndarray, np.ndarray]:
    """Deterministic 1-D Lloyd clustering. Uses sample values, never labels."""
    centers = np.quantile(values, [1/6, .5, 5/6]).astype(float)
    for _ in range(30):
        cluster = np.argmin(abs(values[:, None] - centers[None, :]), axis=1)
        updated = centers.copy()
        for j in range(3):
            if np.any(cluster == j):
                updated[j] = values[cluster == j].mean()
        if max(abs(updated - centers)) < 1e-10:
            break
        centers = updated
    centers = np.sort(centers)
    cluster = np.argmin(abs(values[:, None] - centers[None, :]), axis=1)
    counts = np.bincount(cluster, minlength=3)
    if not np.all(np.diff(centers) > 0):
        raise ValueError("Unlabeled bootstrap could not form three ordered groups")
    return centers, counts


def detector(samples: np.ndarray, initial: np.ndarray, *, age_prediction: bool) -> np.ndarray:
    """V2 rule, or a V3 predictor that ages a stale high-center observation.

    On V3, the estimated high center moves from its observed estimate toward
    c1+q(c1-c0) if there have been no accepted high observations for 96
    samples. This is a model assumption, not information from the true signal.
    """
    centers = initial.astype(float).copy()
    ratio = (centers[2] - centers[1]) / (centers[1] - centers[0])
    age_high = 0
    result = np.empty(len(samples), dtype=np.uint8)
    for k, raw in enumerate(samples):
        sample = float(raw)
        gaps = np.diff(centers)
        predicted_high = centers[1] + ratio*gaps[0]
        observed_weight = math.exp(-age_high/96) if age_prediction else 1.0
        effective_high = observed_weight*centers[2] + (1-observed_weight)*predicted_high
        t1 = .5*(centers[0] + centers[1])
        t2 = .5*(centers[1] + effective_high)
        chosen = 0 if sample < t1 else (1 if sample < t2 else 2)
        result[k] = chosen
        age_high += 1
        if chosen == 0:
            accepted = gaps[0] > 0 and abs(sample-centers[0]) <= .45*gaps[0]
        elif chosen == 1:
            accepted = min(gaps) > 0 and abs(sample-centers[1]) <= .45*min(gaps)
        else:
            # V3 raises confidence before trusting a high assignment, since
            # a shifted middle symbol can masquerade as a high symbol.
            required_fraction = .9 if age_prediction else .5
            accepted = (ratio*gaps[0] > 0 and
                        sample >= centers[1] + required_fraction*ratio*gaps[0])
        if accepted:
            centers[chosen] += ALPHA*(sample-centers[chosen])
            if chosen == 2:
                age_high = 0
    return result


def fixed_decisions(samples: np.ndarray, initial_high: np.ndarray) -> np.ndarray:
    estimated_gain = float(initial_high.mean()/2)
    return np.clip(np.floor(samples/estimated_gain+.5),0,2).astype(np.uint8)


def metrics(truth: np.ndarray, decisions: np.ndarray, half: int):
    assert len(truth) == len(decisions)
    errors = truth != decisions
    return {
        "overall_ser": float(errors.mean()),
        "post_ser": float(errors[half:].mean()),
        "early_ser": float(errors[half:half+1200].mean()),
        "late_ser": float(errors[-1200:].mean()),
        "false_transition_rate": float(np.mean((decisions[1:] != decisions[:-1]) &
                                               (truth[1:] == truth[:-1]))),
        "missed_transition_rate": float(np.mean((decisions[1:] == decisions[:-1]) &
                                                (truth[1:] != truth[:-1]))),
        **{f"level_{j}_error_count": int(np.sum(errors & (truth==j))) for j in range(3)},
        **{f"level_{j}_count": int(np.sum(truth==j)) for j in range(3)},
    }


def to_csv(path: Path, records: list[dict]) -> None:
    with path.open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(records[0]))
        writer.writeheader()
        writer.writerows(records)


def self_checks():
    known = np.array([0.0, 1.0, 2.0])
    truth = np.tile(np.arange(3,dtype=np.uint8), 100)
    for age_prediction in (False, True):
        result = detector(truth.astype(float), known, age_prediction=age_prediction)
        assert np.array_equal(result, truth)
        prefix = truth.astype(float)
        a = detector(np.r_[prefix, np.zeros(100)], known, age_prediction=age_prediction)
        b = detector(np.r_[prefix, np.full(100, 9.0)], known, age_prediction=age_prediction)
        assert np.array_equal(a[:len(prefix)], b[:len(prefix)])
    sample = np.repeat(known, 20)
    centers, counts = blind_centers(sample)
    assert np.allclose(centers, known) and np.all(counts==20)


def run(output: Path, seeds: int, length: int, seed_base: int, suite: str) -> None:
    if length < 8000 or length % 2:
        raise ValueError("Use an even data length >= 8000")
    self_checks()
    output.mkdir(parents=True, exist_ok=True)
    cases = DEV if suite == "development" else VALID
    rows: list[dict] = []
    bootstrap_details: list[dict] = []
    for case in cases:
        for replicate in range(seeds):
            seed = seed_base + replicate
            rng = np.random.default_rng(seed)
            truth = rng.integers(0, 3, length, dtype=np.uint8)
            truth, levels, gain, offset, sigma = make_case(case, truth, rng)
            raw = offset + gain*levels[truth] + rng.normal(0,1,length)*sigma
            pilot_labels = np.repeat(np.arange(3), PILOT_COUNTS)
            pilot_values = levels[pilot_labels] + rng.normal(0,.18,len(pilot_labels))
            pilot_centers = np.array([pilot_values[pilot_labels==j].mean() for j in range(3)])
            for protocol in ("labelled_16", "blind_192"):
                start = 0 if protocol == "labelled_16" else BOOTSTRAP
                evaluation = raw[start:]
                eval_truth = truth[start:]
                half = length//2-start
                if protocol == "labelled_16":
                    centers = pilot_centers.copy()
                    high_buffer = pilot_values[pilot_labels==2]
                    cluster_counts = PILOT_COUNTS
                else:
                    centers, cluster_counts = blind_centers(raw[:BOOTSTRAP])
                    pseudo = np.argmin(abs(raw[:BOOTSTRAP,None]-centers[None,:]),axis=1)
                    high_buffer = raw[:BOOTSTRAP][pseudo==2][-16:]
                bootstrap_details.append({"suite":suite,"case":case,"seed":seed,"protocol":protocol,
                                          "true_high_seen_bootstrap":int(np.sum(truth[:BOOTSTRAP]==2)) if protocol=="blind_192" else -1,
                                          "cluster_low_count":int(cluster_counts[0]),
                                          "cluster_mid_count":int(cluster_counts[1]),
                                          "cluster_high_count":int(cluster_counts[2]),
                                          "c0":float(centers[0]),"c1":float(centers[1]),"c2":float(centers[2]),
                                          "song_high_buffer_size":len(high_buffer)})
                song, _, _, _ = selective_store(evaluation, high_buffer, 3)
                ideal_centers = offset[start:,None] + gain[start:,None]*levels[None,:]
                predictions = {
                    "fixed":fixed_decisions(evaluation,high_buffer),
                    "song_kam":song,
                    "v2_three_centers":detector(evaluation, centers, age_prediction=False),
                    "v3_age_affine":detector(evaluation, centers, age_prediction=True),
                    "oracle":np.argmin((evaluation[:,None]-ideal_centers)**2,axis=1).astype(np.uint8),
                }
                for method, decided in predictions.items():
                    rows.append({"suite":suite,"case":case,"seed":seed,"protocol":protocol,"method":method,
                                 "n_scored":len(eval_truth),"pilots":16 if protocol=="labelled_16" else 0,
                                 "unlabelled_bootstrap":start,
                                 **metrics(eval_truth, decided, half)})
    to_csv(output/"replicate_metrics.csv",rows)
    to_csv(output/"bootstrap_diagnostics.csv",bootstrap_details)
    summary: list[dict] = []
    for protocol in ("labelled_16", "blind_192"):
        for case in cases:
            for method in METHODS:
                subset = [r for r in rows if r["case"]==case and r["protocol"]==protocol and r["method"]==method]
                values = np.array([r["post_ser"] for r in subset])
                mu = float(values.mean())
                half_ci = 1.96*float(values.std(ddof=1))/math.sqrt(seeds) if seeds>1 else 0.0
                summary.append({"suite":suite,"protocol":protocol,"case":case,"method":method,
                                "n_seeds":seeds,"n_scored_each":subset[0]["n_scored"],
                                "mean_post_ser":mu,"ci_low":max(0.0,mu-half_ci),"ci_high":min(1.0,mu+half_ci),
                                "mean_early_ser":float(np.mean([r["early_ser"] for r in subset])),
                                "mean_late_ser":float(np.mean([r["late_ser"] for r in subset])),
                                "mean_false_transition_rate":float(np.mean([r["false_transition_rate"] for r in subset]))})
                assert summary[-1]["ci_low"]<=mu<=summary[-1]["ci_high"]
    to_csv(output/"summary.csv", summary)
    paired = []
    for protocol in ("labelled_16", "blind_192"):
        for case in cases:
            for seed in range(seed_base,seed_base+seeds):
                by_method = {r["method"]:r for r in rows if r["protocol"]==protocol and r["case"]==case and r["seed"]==seed}
                for candidate in ("v2_three_centers", "v3_age_affine"):
                    paired.append({"suite":suite,"protocol":protocol,"case":case,"seed":seed,
                                   "candidate":candidate,"against":"song_kam",
                                   "delta_post_ser":by_method[candidate]["post_ser"]-by_method["song_kam"]["post_ser"],
                                   "delta_early_ser":by_method[candidate]["early_ser"]-by_method["song_kam"]["early_ser"]})
    to_csv(output/"paired_differences.csv",paired)
    # Use a compact visual for the six named scenarios in each protocol.
    for protocol in ("labelled_16", "blind_192"):
        fig, ax = plt.subplots(figsize=(11,5.5))
        for j,method in enumerate(METHODS[:-1]):
            values=[next(r["mean_post_ser"] for r in summary if r["protocol"]==protocol and
                         r["case"]==case and r["method"]==method) for case in cases]
            ax.bar(np.arange(len(cases))+(j-1.5)*.2,values,.19,label=method.replace("_"," "))
        ax.set_xticks(range(len(cases)),[c.replace("_"," ") for c in cases],rotation=22,ha="right")
        ax.set_ylabel("SER after intervention")
        ax.set_title(f"{protocol}: same initialization observations and data within protocol")
        ax.grid(axis="y",alpha=.22)
        ax.legend(fontsize=8)
        fig.tight_layout()
        fig.savefig(output/f"comparison_{protocol}.png",dpi=160)
        plt.close(fig)
    (output/"metadata.json").write_text(json.dumps({"suite":suite,"seed_base":seed_base,"seeds":seeds,
        "symbols_per_seed":length,"labelled_pilots_per_class":PILOT_COUNTS,
        "blind_unlabelled_bootstrap":BOOTSTRAP,"online_alpha":ALPHA,
        "v3_high_age_time_constant_symbols":96,
        "v3_difference_from_v2":"Blend high center with c1+q(c1-c0) by exp(-time_since_accepted_high/96); require 0.9 predicted gap for high acceptance, versus 0.5 in V2.",
        "source":"https://arxiv.org/pdf/1505.02536",
        "scope":"Generic synthetic ternary voltage; not Proteus or original FSO curves"},indent=2),encoding="utf-8")


if __name__=="__main__":
    parser=argparse.ArgumentParser()
    parser.add_argument("--output",type=Path,default=Path("stage6_results"))
    parser.add_argument("--suite",choices=("development","validation"),default="development")
    parser.add_argument("--seeds",type=int,default=8)
    parser.add_argument("--length",type=int,default=12000)
    parser.add_argument("--seed-base",type=int,default=20260929)
    args=parser.parse_args()
    run(args.output,args.seeds,args.length,args.seed_base,args.suite)
