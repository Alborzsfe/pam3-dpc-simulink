"""Independent check of an actual .m run against the supplied Python oracle.

Only for development/verification. MATLAB users do not need Python.
Usage: python3 tests/reference_check.py results_reference/comparison_result.mat
Requires numpy and scipy.
"""
import json
import sys
from pathlib import Path

import numpy as np
from scipy.io import loadmat

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / "PAM3_original"))
from python_reference.model import decode, DecoderConfig  # noqa: E402


def gaussian(n, seed):
    state = int(seed)
    out = np.zeros(n)
    for k in range(0, n, 2):
        state = 16807 * state % 2147483647
        u1 = state / 2147483647
        state = 16807 * state % 2147483647
        u2 = state / 2147483647
        radius = np.sqrt(-2 * np.log(u1))
        out[k] = radius * np.cos(2 * np.pi * u2)
        if k + 1 < n:
            out[k + 1] = radius * np.sin(2 * np.pi * u2)
    return out


def main(path):
    r = loadmat(path, simplify_cells=True)["result"]
    cfg = r["config"]
    data = r["input"]
    n = len(data["t"])
    spp = round(cfg["fs_hz"] / cfg["f0_hz"])
    clean = np.tile(
        cfg["amplitude"] * np.sin(2 * np.pi * np.arange(spp) / spp),
        n // spp,
    )
    ix = np.asarray(data["measure_index"], dtype=int) - 1
    noise = gaussian(n, cfg["seed"])
    noise -= np.mean(noise[ix])
    noise *= (
        np.sqrt(np.mean(clean[ix] ** 2))
        * 10 ** (-cfg["noise_snr_db"] / 20)
        / np.sqrt(np.mean(noise[ix] ** 2))
    )
    analog = np.column_stack([clean, clean + noise])
    adc = np.clip(
        np.floor(cfg["adc_center"] + cfg["adc_gain"] * analog + 0.5), 0, 255
    )
    assert np.max(np.abs(data["analog"] - analog)) < 1e-12
    np.testing.assert_array_equal(data["adc"], adc)
    normalized = (adc - cfg["adc_center"]) / cfg["adc_gain"]
    output_samples = 0
    for s in range(2):
        d = decode(adc[:, s], DecoderConfig())
        actual_pam3 = r["pam3"][s]
        for field in ["raw_levels", "levels", "points", "symbols"]:
            np.testing.assert_array_equal(actual_pam3[field], d[field])
        # Independent offline oracle gives source indices. Availability is +20.
        held = np.zeros(n)
        for point, symbol in zip(d["points"], d["symbols"]):
            available = int(point) + 20
            if available < n:
                held[available:] = symbol
        h = np.zeros(n)
        state = cfg["hysteresis_initial"]
        for k, value in enumerate(normalized[:, s]):
            if value >= cfg["hysteresis_on"]:
                state = 1
            elif value <= cfg["hysteresis_off"]:
                state = -1
            h[k] = state
        np.testing.assert_array_equal(r["output_levels"][:, 0, s], h)
        np.testing.assert_array_equal(r["output_levels"][:, 1, s], held)
        output_samples += 2 * n
    max_error = 0.0
    harmonics = np.arange(1, int(cfg["max_harmonic"]) + 1)
    theta = 2 * np.pi * cfg["f0_hz"] * np.arange(len(ix)) / cfg["fs_hz"]
    basis = harmonics[:, None] * theta
    for k, row in enumerate(r["rows"]):
        b = k % 2
        s = k // 2
        volts = cfg["output_volts_per_level"] * r["output_levels"][ix, b, s]
        ac = volts - volts.mean()
        # Direct projections, independently of the MATLAB FFT implementation.
        cos_coeff = 2 * (np.cos(basis) @ ac) / len(ac)
        sin_coeff = 2 * (np.sin(basis) @ ac) / len(ac)
        hrms = np.hypot(cos_coeff, sin_coeff) / np.sqrt(2)
        p = volts**2 / cfg["resistance_ohm"]
        residual = ac - cos_coeff[0] * np.cos(theta) - sin_coeff[0] * np.sin(theta)
        expected = {
            "thd_percent": 100 * np.linalg.norm(hrms[1:]) / hrms[0],
            "thdn_percent": 100 * np.sqrt(np.mean(residual**2)) / hrms[0],
            "fundamental_rms_v": hrms[0],
            "mean_power_w": p.mean(),
            "power_ripple_pp_w": np.ptp(p),
            "power_ripple_rms_w": np.std(p),
        }
        for name, value in expected.items():
            error = abs(value - row["metrics"][name])
            assert error < 1e-9, (row["scenario"], row["block"], name, error)
            max_error = max(max_error, float(error))
    report = {
        "passed": True,
        "same_input_adc_samples_checked": int(2 * n),
        "output_samples_checked": output_samples,
        "original_pam3_raw_filtered_symbols_and_indices_match": True,
        "independent_projection_metric_max_abs_error": max_error,
        "matlab_executed": bool(r["matlab_executed"]),
        "runtime_product": r["runtime_product"],
        "simulink_executed": False,
    }
    (path.parent / "independent_check.json").write_text(
        json.dumps(report, indent=2), encoding="utf-8"
    )
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main(Path(sys.argv[1]).resolve())
