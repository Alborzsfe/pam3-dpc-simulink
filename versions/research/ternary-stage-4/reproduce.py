"""Free-software, reproducible study of Song and Kam (2015), arXiv:1505.02536v1.

The decision-feedback receiver follows Eqs. (11) and (13). Starting pilots,
gain normalization and random-stream details are explicitly marked as
implementation choices because they are not completely specified in the paper.

Usage: python reproduce.py --output results --seed 20260928
       python reproduce.py --quick --output smoke_results
"""

from __future__ import annotations

import argparse
import csv
import json
import math
import platform
from pathlib import Path

import matplotlib

matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import scipy
from scipy.special import ndtr
from scipy.stats import binomtest, gamma as gamma_distribution, qmc


GRAY4 = np.array([0, 1, 3, 2], dtype=np.uint8)
POPCOUNT2 = np.array([0, 1, 1, 2], dtype=np.uint8)


def selective_store(
    samples: np.ndarray,
    pilot_samples: np.ndarray,
    m: int,
    *,
    trace_stride: int = 0,
) -> tuple[np.ndarray, np.ndarray, np.ndarray, int]:
    """Eq. (13), applied causally: decide with OLD buffer, then update it.

    pilot_samples contain known highest-symbol observations (an explicit
    implementation assumption). A nonpositive estimate is processed with
    Eq. (11), rather than being silently clipped into a different algorithm.
    """
    if m < 2 or pilot_samples.size == 0:
        raise ValueError("At least two levels and one pilot are required")
    buffer = np.asarray(pilot_samples, dtype=np.float64).copy()
    lm = len(buffer)
    head = 0
    total = float(buffer.sum())
    output = np.empty(len(samples), dtype=np.uint8)
    trace_index: list[int] = []
    trace_gain: list[float] = []
    invalid_estimates = 0

    for k in range(len(samples)):
        received = float(samples[k])
        estimate = total / (lm * (m - 1))
        if estimate > 0.0:
            decision = math.floor(received / estimate + 0.5)
            decision = min(m - 1, max(0, decision))
        else:
            invalid_estimates += 1
            decision = min(range(m), key=lambda level: (received - level * estimate) ** 2)
        output[k] = decision
        if trace_stride and k % trace_stride == 0:
            trace_index.append(k)
            trace_gain.append(estimate)
        if decision == m - 1:
            total += received - buffer[head]
            buffer[head] = received
            head = (head + 1) % lm
    return output, np.asarray(trace_index), np.asarray(trace_gain), invalid_estimates


def frozen_slicer(samples: np.ndarray, estimate: float, m: int) -> np.ndarray:
    """Calibrated once with the SAME pilots as the adaptive receiver."""
    if estimate <= 0:
        # Eq. (11) is well defined even when the pilot estimate is nonpositive.
        return np.argmin(
            (samples[:, None] - estimate * np.arange(m)[None, :]) ** 2, axis=1
        ).astype(np.uint8)
    return np.clip(np.floor(samples / estimate + 0.5), 0, m - 1).astype(np.uint8)


def sampled_channel(
    rng: np.random.Generator, n_blocks: int, *, a0: float = 0.0198,
    alpha: float = 2.23, beta: float = 1.54, gamma: float = 2.8071,
) -> np.ndarray:
    """Gamma-Gamma amplitude times the pointing-error distribution, paper (23)-(25).

    Normalizing the product to mean one is our stated interpretation of the
    paper's simultaneous h=h_a*h_p and E[h]=1 statements.
    """
    turbulence = rng.gamma(alpha, 1.0 / alpha, n_blocks) * rng.gamma(
        beta, 1.0 / beta, n_blocks
    )
    pointing = a0 * rng.random(n_blocks) ** (1.0 / (gamma * gamma))
    mean_pointing = a0 * (gamma * gamma) / (gamma * gamma + 1.0)
    return turbulence * pointing / mean_pointing


def balanced_fading_replicates(
    rng: np.random.Generator, frames_per_rep: int, reps: int = 8
) -> np.ndarray:
    """Randomized Sobol samples: independent scrambles, balanced fades within each.

    Each frame is a separate receiver run with a fresh pilot. Scrambled
    replicates let us estimate between-replicate Monte Carlo uncertainty.
    """
    if frames_per_rep < 2 or frames_per_rep & (frames_per_rep - 1):
        raise ValueError("Frames per replicate must be a power of two >= 2")
    a0, alpha, beta, gamma = 0.0198, 2.23, 1.54, 2.8071
    mean_pointing = a0 * gamma**2 / (gamma**2 + 1.0)
    draws = []
    for _ in range(reps):
        sampler = qmc.Sobol(3, scramble=True, seed=int(rng.integers(0, 2**31)))
        u = np.clip(sampler.random_base2(int(math.log2(frames_per_rep))), 1e-12, 1 - 1e-12)
        h = (gamma_distribution.ppf(u[:, 0], a=alpha, scale=1 / alpha)
             * gamma_distribution.ppf(u[:, 1], a=beta, scale=1 / beta)
             * (a0 * u[:, 2] ** (1 / gamma**2)) / mean_pointing)
        draws.append(h)
    return np.concatenate(draws)


def gray_bit_errors(truth: np.ndarray, prediction: np.ndarray) -> np.ndarray:
    return POPCOUNT2[np.bitwise_xor(GRAY4[truth], GRAY4[prediction])]


def genie_bep_from_fades(
    fades: np.ndarray, separation: float, sigma: float, m: int = 4
) -> float:
    """Expected BER with TRUE channel gain, Gray-mapped M=4 and Gaussian noise.

    Integrates normal CDF over the decision intervals, then averages over
    independently drawn fades. This does not inject the truth into the receiver.
    """
    if m != 4:
        raise ValueError("Only M=4 has a specified Gray mapping in this study")
    values = separation * fades
    total = np.zeros_like(values)
    edges = np.array([-np.inf, 0.5, 1.5, 2.5, np.inf])
    for sent in range(4):
        z = (edges[None, :] - float(sent)) * (values[:, None] / sigma)
        cdf = ndtr(z)
        for decided in range(4):
            hamming = int(POPCOUNT2[int(GRAY4[sent] ^ GRAY4[decided])])
            total += hamming * (cdf[:, decided + 1] - cdf[:, decided])
    return float(total.mean() / (m * 2))


def replicate_interval(errors: np.ndarray, reps: int = 8) -> tuple[float, float]:
    """Approximate 95% interval from independent randomized Sobol replicates."""
    if len(errors) % reps:
        raise ValueError("Replicates must have identical lengths")
    rates = errors.reshape(reps, -1).mean(axis=1)
    avg = float(errors.mean())
    half = 1.96 * float(rates.std(ddof=1)) / math.sqrt(reps)
    # Gray bit-error COUNT for a four-level symbol can be 0, 1, or 2.
    return max(0.0, avg - half), min(2.0, avg + half)


def wilson_interval(error_count: int, sample_count: int) -> tuple[float, float]:
    z = 1.96
    p = error_count / sample_count
    denom = 1.0 + z * z / sample_count
    center = (p + z * z / (2 * sample_count)) / denom
    half = z * math.sqrt(p * (1 - p) / sample_count + z * z / (4 * sample_count**2)) / denom
    return center - half, center + half


def original_experiment(
    out: Path, rng: np.random.Generator, n_symbols: int, quick: bool
) -> list[dict]:
    """M=4, 10 Gb/s, strong fading, selected curves from Fig. 3(b)."""
    m, rate_bps, coherence, frame_size, n0 = 4, 10.0e9, 10_000, 1_000, 1.59e-22
    assert frame_size <= coherence
    sigma = math.sqrt(n0 / 2)
    symbol_seconds = math.log2(m) / rate_bps
    power_dbm_points = [-23, -20, -17, -14, -11] if quick else [-24, -22, -20, -18, -16, -14, -12, -10]
    if n_symbols % frame_size:
        raise ValueError("The original symbol count must be a multiple of 1000")
    n_blocks = n_symbols // frame_size
    if n_blocks % 8:
        raise ValueError("Use eight equal fading replicates")
    fades = balanced_fading_replicates(rng, n_blocks // 8)
    truth = rng.integers(0, m, size=n_symbols, dtype=np.uint8)
    noise_unit = rng.normal(0, 1, size=n_symbols)
    pilot_noise_unit = rng.normal(0, 1, size=(n_blocks, 16))
    oracle_fades = sampled_channel(np.random.default_rng(76115), 400_000 if not quick else 50_000)
    results: list[dict] = []

    for power_dbm in power_dbm_points:
        power_watts = 10 ** ((power_dbm - 30) / 10)
        minimum_distance = 2 * math.sqrt(symbol_seconds) * power_watts / (m - 1)
        gains = minimum_distance * np.repeat(fades, frame_size)
        samples = gains * truth + sigma * noise_unit
        known_channel = frozen_slicer(samples / gains, 1.0, m)
        oracle_errors = gray_bit_errors(truth, known_channel)
        oracle_interval = replicate_interval(oracle_errors)
        expected_genie = genie_bep_from_fades(oracle_fades, minimum_distance, sigma)
        # Each frame is an independent transmission and is shorter than Lc.
        # Eight randomized quasi-Monte Carlo replicates balance rare fades.
        pilot_noise = sigma * pilot_noise_unit

        row: dict = {
            "power_dbm": power_dbm,
            "symbols": n_symbols,
            "independent_frames": n_blocks,
            "symbols_per_frame": frame_size,
            "fading_scrambles": 8,
            "genie_empirical_bep": float(oracle_errors.mean() / 2),
            "genie_empirical_ci_low": oracle_interval[0] / 2,
            "genie_empirical_ci_high": oracle_interval[1] / 2,
            "genie_independent_fade_bep": expected_genie,
            "mean_simulated_gain": float(fades.mean()),
        }
        for lm in [1, 16]:
            predicted = np.empty(n_symbols, dtype=np.uint8)
            invalid = 0
            for b in range(n_blocks):
                start, stop = b * frame_size, (b + 1) * frame_size
                pilot_samples = (m - 1) * gains[start] + pilot_noise[b, :lm]
                values, _, _, invalid_in_block = selective_store(
                    samples[start:stop], pilot_samples, m
                )
                predicted[start:stop] = values
                invalid += invalid_in_block
            bit_errors = gray_bit_errors(truth, predicted)
            ci = replicate_interval(bit_errors)
            row[f"bep_lm{lm}"] = float(bit_errors.mean() / 2)
            row[f"bep_lm{lm}_ci_low"] = ci[0] / 2
            row[f"bep_lm{lm}_ci_high"] = ci[1] / 2
            row[f"symbol_errors_lm{lm}"] = int(np.count_nonzero(predicted != truth))
            row[f"invalid_gain_lm{lm}"] = invalid
        results.append(row)

    with (out / "original_m4_figure3b.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(results[0]))
        writer.writeheader()
        writer.writerows(results)

    x = np.array([v["power_dbm"] for v in results])
    fig, ax = plt.subplots(figsize=(8.3, 5.2))
    for lm, marker, color in [(1, "s", "#ae5a2a"), (16, "o", "#256392")]:
        ax.errorbar(
            x, [v[f"bep_lm{lm}"] for v in results],
            yerr=[
                [v[f"bep_lm{lm}"] - v[f"bep_lm{lm}_ci_low"] for v in results],
                [v[f"bep_lm{lm}_ci_high"] - v[f"bep_lm{lm}"] for v in results],
            ],
            fmt=marker + "-", color=color, capsize=3, label=f"Decision feedback, Lm={lm}",
        )
    ax.plot(x, [v["genie_empirical_bep"] for v in results], "^--", color="#629e63", label="True gain, same samples")
    ax.plot(x, [v["genie_independent_fade_bep"] for v in results], "k:", label="True gain, independent fade integration")
    ax.set_yscale("log")
    ax.set_xlabel("Average received optical power (dBm)")
    ax.set_ylabel("Bit error probability (Gray-coded, M=4)")
    ax.set_title("Fig. 3b: M=4, 10 Gb/s, SI=1.389; independent coherent frames")
    ax.grid(True, which="both", alpha=0.28)
    ax.legend(fontsize=8)
    fig.tight_layout()
    fig.savefig(out / "original_m4_figure3b.png", dpi=170)
    plt.close(fig)
    return results


def ternary_experiment(
    out: Path, rng: np.random.Generator, n_symbols: int, sigma: float = 0.18
) -> list[dict]:
    m, lm = 3, 16
    truth = rng.integers(0, m, size=n_symbols, dtype=np.uint8)
    noise = rng.normal(0.0, sigma, size=n_symbols)
    pilot_noise = rng.normal(0.0, sigma, size=lm)
    pilot_samples = 2.0 + pilot_noise
    initial_gain = float(pilot_samples.mean() / 2)
    rows: list[dict] = []
    confusion_rows: list[dict] = []
    paired_rows: list[dict] = []
    fig, ax = plt.subplots(figsize=(8.3, 5.1))

    for case, gain in [
        ("constant_gain", np.ones(n_symbols, dtype=float)),
        ("slow_gain_ramp", np.linspace(1.0, 1.2, n_symbols)),
    ]:
        received = gain * truth + noise
        adaptive, sample_idx, estimates, invalid = selective_store(
            received, pilot_samples, m, trace_stride=max(1, n_symbols // 300)
        )
        frozen = frozen_slicer(received, initial_gain, m)
        ideal = np.clip(np.floor(received / gain + 0.5), 0, m - 1).astype(np.uint8)
        for method, decisions in [
            ("adaptive_song2015_m3_transfer", adaptive),
            ("frozen_thresholds_equal_pilots", frozen),
            ("oracle_true_gain_not_practical", ideal),
        ]:
            wrong = decisions != truth
            counts = [int(np.count_nonzero(wrong & (truth == j))) for j in range(m)]
            class_total = [int(np.count_nonzero(truth == j)) for j in range(m)]
            nerr = int(wrong.sum())
            low, high = wilson_interval(nerr, n_symbols)
            rows.append({
                "case": case, "method": method, "symbols": n_symbols,
                "pilot_symbols": lm, "noise_sd_in_A0_units": sigma,
                "initial_gain_from_pilots": initial_gain,
                "symbol_errors": nerr, "ser": nerr / n_symbols,
                "approx_wilson_ci_low": low, "approx_wilson_ci_high": high,
                "low_errors": counts[0], "mid_errors": counts[1], "high_errors": counts[2],
                "low_count": class_total[0], "mid_count": class_total[1], "high_count": class_total[2],
                "nonpositive_estimates": invalid if method.startswith("adaptive_") else 0,
            })
            matrix = np.bincount(3 * truth.astype(np.int32) + decisions, minlength=9).reshape(3, 3)
            for true_level in range(m):
                for decided_level in range(m):
                    confusion_rows.append({"case": case, "method": method,
                                           "true_level": true_level, "decided_level": decided_level,
                                           "count": int(matrix[true_level, decided_level])})
        adaptive_wrong, frozen_wrong = adaptive != truth, frozen != truth
        adaptive_only = int(np.count_nonzero(adaptive_wrong & ~frozen_wrong))
        frozen_only = int(np.count_nonzero(frozen_wrong & ~adaptive_wrong))
        paired_rows.append({
            "case": case, "symbols": n_symbols,
            "adaptive_only_errors": adaptive_only, "frozen_only_errors": frozen_only,
            "absolute_ser_reduction_frozen_minus_adaptive": (frozen_only - adaptive_only) / n_symbols,
            "exact_p_for_equal_discordant_counts": binomtest(
                adaptive_only, adaptive_only + frozen_only, p=0.5
            ).pvalue if adaptive_only + frozen_only else 1.0,
        })
        if case == "slow_gain_ramp":
            ax.plot(sample_idx, estimates / 2, color="#ae5a2a", lw=1.2, label="adaptive lower threshold")
            ax.plot(sample_idx, 1.5 * estimates, color="#256392", lw=1.2, label="adaptive upper threshold")
            ax.plot(sample_idx, gain[sample_idx] / 2, "--", color="#ae5a2a", alpha=0.65, label="ideal lower boundary")
            ax.plot(sample_idx, 1.5 * gain[sample_idx], "--", color="#256392", alpha=0.65, label="ideal upper boundary")
            ax.axhline(initial_gain / 2, linestyle=":", color="gray", label="frozen lower")
            ax.axhline(1.5 * initial_gain, linestyle=":", color="black", label="frozen upper")
            with (out / "ternary_threshold_trace.csv").open("w", newline="", encoding="utf-8") as handle:
                writer = csv.writer(handle)
                writer.writerow(["data_index", "true_gain", "estimated_gain", "adaptive_t1", "adaptive_t2", "frozen_t1", "frozen_t2"])
                for idx, est in zip(sample_idx, estimates, strict=True):
                    writer.writerow([int(idx), float(gain[idx]), float(est), float(est / 2), float(est * 1.5), initial_gain / 2, initial_gain * 1.5])

    with (out / "ternary_m3_results.csv").open("w", newline="", encoding="utf-8") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    for filename, records in [
        ("ternary_confusion_matrices.csv", confusion_rows),
        ("ternary_paired_comparison.csv", paired_rows),
    ]:
        with (out / filename).open("w", newline="", encoding="utf-8") as handle:
            writer = csv.DictWriter(handle, fieldnames=list(records[0]))
            writer.writeheader()
            writer.writerows(records)
    ax.set_xlabel("Data symbol index (pilots excluded)")
    ax.set_ylabel("Decision threshold (normalized sample units)")
    ax.set_title("M=3 transfer: gain increases slowly from 1.0 to 1.2")
    ax.grid(alpha=0.28)
    ax.legend(ncol=2, fontsize=8)
    fig.tight_layout()
    fig.savefig(out / "ternary_thresholds.png", dpi=170)
    plt.close(fig)

    labels = ["Constant gain", "Slow ramp"]
    methods = ["adaptive_song2015_m3_transfer", "frozen_thresholds_equal_pilots", "oracle_true_gain_not_practical"]
    fig, ax = plt.subplots(figsize=(7.6, 4.8))
    for j, method in enumerate(methods):
        vals = [next(z["ser"] for z in rows if z["case"] == case and z["method"] == method) for case in ["constant_gain", "slow_gain_ramp"]]
        ax.bar(np.arange(2) + (j - 1) * 0.23, vals, 0.22, label=method.replace("_", " "), alpha=0.85)
    ax.set_xticks(range(2), labels)
    ax.set_ylabel("Level decision error rate (SER)")
    ax.set_title("Same symbols, noise, and pilot samples in each paired comparison")
    ax.legend(fontsize=7)
    ax.grid(axis="y", alpha=0.25)
    fig.tight_layout()
    fig.savefig(out / "ternary_ser_comparison.png", dpi=170)
    plt.close(fig)
    return rows


def self_checks() -> dict:
    """Three distinct validity risks: truth leakage, ideal noise baseline, noiseless correctness."""
    rng = np.random.default_rng(901)
    pilot = np.array([3.0] * 12)
    for m in [3, 4]:
        truth = np.tile(np.arange(m, dtype=np.uint8), 40)
        received = truth.astype(float)
        pilots = np.full(12, m - 1, dtype=float)
        predicted, _, _, invalid = selective_store(received, pilots, m)
        assert np.array_equal(predicted, truth) and invalid == 0

    first_half = np.tile(np.arange(4, dtype=np.uint8), 80).astype(float)
    extension_a = np.zeros(320)
    extension_b = np.full(320, 30.0)
    a, _, _, _ = selective_store(np.concatenate([first_half, extension_a]), pilot, 4)
    b, _, _, _ = selective_store(np.concatenate([first_half, extension_b]), pilot, 4)
    assert np.array_equal(a[: len(first_half)], b[: len(first_half)])

    n = 150_000
    truth = rng.integers(0, 4, n, dtype=np.uint8)
    sigma = 0.48
    samples = truth + rng.normal(0, sigma, n)
    empirical = float(gray_bit_errors(truth, frozen_slicer(samples, 1.0, 4)).mean() / 2)
    exact = genie_bep_from_fades(np.array([1.0]), 1.0, sigma)
    assert abs(empirical - exact) < 0.0045, (empirical, exact)
    return {"noiseless_m3_m4": True, "causal_future_invariance": True,
            "awgn_oracle_simulation_bep": empirical, "awgn_oracle_normal_cdf_bep": exact}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", default="results")
    parser.add_argument("--seed", type=int, default=20260928)
    parser.add_argument("--quick", action="store_true")
    parser.add_argument("--original-symbols", type=int, default=None)
    parser.add_argument("--ternary-symbols", type=int, default=None)
    args = parser.parse_args()
    output = Path(args.output)
    output.mkdir(parents=True, exist_ok=True)
    original_n = args.original_symbols or (128_000 if args.quick else 1_024_000)
    ternary_n = args.ternary_symbols or (30_000 if args.quick else 300_000)
    checks = self_checks()
    rng = np.random.default_rng(args.seed)
    orig = original_experiment(output, rng, original_n, args.quick)
    ternary = ternary_experiment(output, rng, ternary_n)
    metadata = {
        "paper": "Song and Kam, arXiv:1505.02536v1, Eqs. (2), (3), (11), (13), Fig. 3b",
        "source": "https://arxiv.org/pdf/1505.02536",
        "seed": args.seed, "quick": args.quick,
        "original_symbols_per_power": original_n, "ternary_symbols_per_case": ternary_n,
        "python": platform.python_version(), "numpy": np.__version__, "scipy": scipy.__version__,
        "matplotlib": matplotlib.__version__,
        "explicit_assumptions": [
            "Initial Lm pilots are all the highest level; the article does not give their exact composition.",
            "Turbulence is product of independent unit-mean gamma variables.",
            "Pointing error is sampled from Eq. (24) and the product is normalized to E[h]=1.",
            "Independent runs of 1000 data symbols each (shorter than Lc=10000); fresh pilot per run. Not one receiver surviving gain jumps.",
            "Eight independent scrambled Sobol replicates balance rare fades; the 95% intervals are approximate across the eight replicate rates.",
            "Identical fading, symbols and Gaussian noise at each power point reduce differences caused by Monte Carlo randomness.",
            "4-PAM symbol mapping is binary-reflected Gray: 0:00,1:01,2:11,3:10.",
            "Pilot overhead excluded from article-style BEP; pilot count separately recorded.",
            "No paper curve points are digitized; plotted Genie reference uses our stated channel normalization.",
        ],
        "checks": checks,
    }
    (output / "run_metadata.json").write_text(json.dumps(metadata, indent=2, ensure_ascii=False), encoding="utf-8")
    print("Checks:", json.dumps(checks))
    print("Original M=4 data:")
    for row in orig:
        print(row["power_dbm"], "dBm, BEP Lm=1", f'{row["bep_lm1"]:.5g}',
              "Lm=16", f'{row["bep_lm16"]:.5g}',
              "Genie empirical", f'{row["genie_empirical_bep"]:.5g}')
    print("M=3 SER:")
    for row in ternary:
        print(row["case"], row["method"], f'{row["ser"]:.6g}', "errors", row["symbol_errors"])


if __name__ == "__main__":
    main()
