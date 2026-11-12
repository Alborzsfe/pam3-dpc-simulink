# Validation status

Numerical environment: Octave 8.4.0, Linux. MATLAB/Simulink not installed here.

- PASS: 40 independent Python offline reference cases, 27,136 input samples; both proposed variants at both control sample rates.
- PASS: coherent sinusoid, known 50% harmonic THD, DC rejection, harmonic-51 exclusion with residual RMS, zero fundamental handling, noncoherent-window rejection.
- PASS: peak-to-peak/RMS ripple and zero-mean relative-ripple handling.
- PASS: duplicate timestamps, single-point constant vectors, 3D vector logging reshaping.
- PASS: synthetic signal pipeline with known THD, P ripple and six-device equivalent switching rate; false execution provenance retained in exported MAT data.
- PASS: synthetic inputs rejected by professor-figure export guard.
- PASS: original source SLX unchanged, SHA256 `c637ed60cde46882b00b42aefcaf2d51796233b7814fdf6bbf72d947dcafd9a9`; expected source blocks, relay thresholds and sector-boundary patch strings verified.
- PASS: static MATLAB syntax lint with MISS_HIT.
- PASS (2026-10-15 patch): fixture-7 timing regression reproduced 31 false mismatches with perfect values under the old previous-ZOH comparison; exact sample indexing gives zero. Actual value changes are preserved, and missing samples / actual clock shifts are rejected. See `sample_alignment_report.mat`.
- PASS (R2024b input-array revision): 8 two-column fixture arrays and the actual S-function Outputs/Update callbacks, invoked with a test-double block object, match 20,928 golden samples. This is NOT native Simulink; see `callback_contract_report.mat`.
- NOT EXECUTED HERE: native Simulink S-function preflight, generated power models, four closed-loop converter simulations, powergui GUI cross-check, MATLAB figure rendering, plant-step convergence study.

`numerical_validation_report.mat` records numerical execution only (`simulink_executed=false`).
Run `START_CONTROL_QUALITY` in MATLAB R2024b to execute the native preflight and actual converter study. `native_controller_report.mat` will then record the native controller preflight; actual converter results are saved separately in `results`.

No converter THD/ripple performance values or professor screenshots are prefilled in this delivery. The supplied source model was previously executed by the user; that is not validation of these new closed-loop modifications.
