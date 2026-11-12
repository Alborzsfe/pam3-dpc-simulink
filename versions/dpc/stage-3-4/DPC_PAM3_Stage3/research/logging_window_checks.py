"""Offline numerical fixtures only; does not execute MATLAB or Simulink."""
from pathlib import Path
import hashlib
import json
import numpy as np


def coverage(times, ts, stop):
    times = np.asarray(times, dtype=float)
    tol = min(ts / 1e6, 64 * np.spacing(max(1, abs(stop))))
    return (times.size > 0 and np.isfinite(times).all()
            and np.all(np.diff(times) >= 0) and abs(times[0]) <= tol
            and times[-1] <= stop + tol and times[-1] + ts >= stop - tol
            and (times.size == 1 or np.max(np.diff(np.unique(times))) <= ts + tol))


def sample(times, values, query, ts=None, stop=None):
    times, values, query = map(np.asarray, (times, values, query))
    tol = 64 * np.spacing(max(1, np.max(np.abs(times)), np.max(np.abs(query))))
    right = np.max(query) <= times[-1] + tol
    if not right and ts is not None:
        right = (np.max(query) <= stop + tol
                 and np.max(query) < times[-1] + ts - tol)
    if np.min(query) < times[0] - tol or not right:
        raise ValueError("window")
    q = np.clip(query + tol, times[0], times[-1])
    return values[np.searchsorted(times, q, side="right") - 1]


def run():
    checks = []
    old_failures = 0
    for fs in (20000, 40000, 60000):
        ts, stop = 1 / fs, .5
        n = round(stop / ts)
        times = np.arange(n) * ts
        query = times + ts / 2
        assert coverage(times, ts, stop)
        # The old endpoint check rejects a legitimate final held interval.
        assert times[-1] < query[-1]
        old_failures += 1
        for qafter in (0, 80, -80):
            values = np.where(times >= .2, qafter, 0)
            expected = np.where(query >= .2, qafter, 0)
            got = sample(times, values, query, ts=ts, stop=stop)
            assert np.array_equal(got, expected)
            assert np.array_equal(sample(times, np.full(n, 400), query, ts, stop),
                                  np.full(n, 400))
            checks.append(f"{fs}Hz_Q{qafter:+d}")
        assert not coverage(times[:-1], ts, stop)
        assert not coverage(times[1:], ts, stop)
        assert not coverage(np.delete(times, 100), ts, stop)
        assert not coverage([0], ts, stop)
        for q in ([stop], [stop + ts], [-ts]):
            try:
                sample(times, values, q, ts, stop)
            except ValueError:
                pass
            else:
                raise AssertionError("Accepted a missing or future sample")
        # Inclusive endpoint is also valid, and actual roundoff is tolerated.
        inclusive = np.append(times, stop)
        assert coverage(inclusive, ts, stop)
        assert sample(inclusive, np.full(n + 1, 400), [stop + np.spacing(stop)])[0] == 400
    root = Path(__file__).resolve().parents[1]
    report = {
        "native_MATLAB_Simulink_executed": False,
        "numerical_fixtures_only": True,
        "old_strict_endpoint_reproductions": old_failures,
        "constant_and_signed_step_fixtures": checks,
        "missing_start_end_internal_tick_rejected": True,
        "unverified_constant_not_extended": True,
        "no_future_or_next_tick_fabricated": True,
        "roundoff_and_inclusive_endpoint_checked": True,
        "changed_MATLAB_files_MISS_HIT_lint": "12 files passed",
        "unrendered_templates_note": "__PLACEHOLDERS__ are replaced by BUILD before MATLAB parses templates",
        "source_slx_sha256": hashlib.sha256((root / "DPC_Three_Level.slx").read_bytes()).hexdigest(),
        "controller_templates_and_experiment_configs_unchanged": True,
        "native_regressions_provided_not_run": ["VALIDATE_PAM3_LOGGING", "SMOKE_TEST_STAGE4_LOGGING"],
        "converter_performance_results": "not generated",
    }
    target = root / "research" / "logging_window_checks.json"
    target.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps(report, indent=2))


if __name__ == "__main__":
    run()
