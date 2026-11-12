# Scope and interpretation

This is an open-loop **identical-input detector experiment**, built around the supplied DPC model. The converter remains under its original dp/dq control during capture. Parallel decisions are evaluated on stored errors, not fed to the bridge.

The supplied root model has `dp` and `dq` Relay blocks with on/off thresholds +1/-1. Their explicitly loaded native on/off outputs are read at run time. The wired inputs are `Pref - P` and `Qref - Q`. `Qref` is zero. Root block `Subsystem1` implements the binary switching table, with four dp/dq combinations across twelve sectors. Its gate path is kept intact.

No embedded MATLAB workspace supplies `Ts` or `e`. Phase-C sine blocks have a stored sample time of 5e-6 s. Other parameter values are documented as benchmark assumptions if the original setup is unavailable. A successful run with assumed `e` is a reproducible **new scenario**, not reproduction of undisclosed original operating conditions.

## Three routes and four diagnostic outputs

1. Sampled binary relay: original thresholds/output values, initial OFF. Its native output is also mapped to -1/+1 for sign diagnostics, by an explicitly reported display conversion.
2. New control adapter: subtract the center of the original band; apply a positive Schmitt relay to x and a second to -x; subtract their 0/1 states. Activation is H, release is rH. This gives -1/0/+1, with zero representing an inactive error decision.
3. Previous full patent core: a static affine power-error-to-ADC calibration, then the unchanged direction/four-threshold decoder, spike filter, edge rules, sampling and symbol output. Report the sample-rate raw and **causal** filtered outputs separately. Sparse symbols are plotted at their output-availability time and excluded from dense decision metrics.

For +1/-1 relay boundaries, ADC offset=117.5 and gain=22.5. Patent threshold codes [140,95,160,80] correspond to error values [1,-1,1.8888889,-1.6666667]. Quantization and saturation prevent asserting that the mapped patent boundaries exactly equal a floating-point relay's behavior. The additional neutral-direction thresholds are asymmetric and extend beyond the original band. Retaining this behavior makes the direct-transfer limitation observable.

The new control adapter is a proposal, not a literal implementation of a disclosed converter patent claim. Its neutral state is not assumed to equal a zero voltage vector, unchanged gate vector, or zero power. That mapping requires closed-loop converter design.

## Sampling and latency

Native converter traces are saved. To make replay deterministic, traces are resampled on a common Ts grid using causal zero-order hold. Values at duplicate timestamps use the last logged value. Solver maximum step is limited to Ts for this recording scenario; solver type and source gate table remain as supplied. Observed relay versus replay mismatch is reported without suppressing it. A nonzero mismatch can reflect continuous-time intermediate switching events; it is not proof of a PAM3 defect.

The spike-filter value for source index q becomes available at q+2. Symbol output for chosen source index q becomes available at q+20. At Ts=5 us these delays are 10 us and 100 us. Metrics compare **availability-time** decisions against the current error, with an identical common validity window for every method. They do not backdate the filtered output to make the response appear faster.

Metrics include output transition counts/rates, neutral fraction, sign mismatch outside the outer band, active fraction inside the release band, mean/max response delay for completed outer-band episodes, and missed episodes. The final sample is included in sample fractions; transition counts use only adjacent valid samples. Runtime inputs are error values, not communication labels, so SER is not defined here.

## Further closed-loop work

Only after inspecting actual results: select the candidate detector and release ratio; define the control meaning of the nine ternary P/Q combinations for every sector; analyze admissible vectors and dead time; run both full controllers under identical external references, load, grid, initial conditions and solver settings. Then measure tracking RMSE/IAE, steady-state P/Q ripple, per-device switching events, current distortion, and losses if a loss model is included. The internal errors will generally differ between closed-loop controllers even under identical external conditions.

The current experiment does not conclude that fewer decisions improve conversion performance. A detector that fails to respond can also produce fewer transitions.
