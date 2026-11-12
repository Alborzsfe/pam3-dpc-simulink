# Validation status — DPC Ternary Noise Study revision 1

Preparation environment: Python/SciPy, GNU Octave 8.4.0 and MISS_HIT syntax
parser. MATLAB/Simulink and Specialized Power Systems are NOT installed here.
No converter performance data or figures are included as precomputed results.

Actually completed locally:

- Original source SLX SHA-256 retained; all three source-to-measurement
  electrical connection endpoints checked directly against its XML.
- Original revision-2 numerical regression: 696 independent table contexts,
  862 classifier/table stream samples, all nine state pairs and 12 sectors,
  both controller rates; the native Relay boundary regression is retained.
- Original S-function callbacks with a test-double block: 1724 sample steps.
- New measured/noisy-power table: 648 contexts against an independent Python
  ABC quadrature + exhaustive-vector oracle; all nine pairs, all 12 sectors,
  both controller rates, several voltage and power noise magnitudes.
- New 11-input table callback path: 216 streaming sample steps against that
  oracle, including repeated Outputs purity and state updates; test double,
  NOT native Simulink. Maximum relative audit discrepancy: below 5e-13.
- Sensor record determinism, changed-seed distinction, exact active-interval
  RMS, zero pre-disturbance noise and global RNG-state restoration.
- 3%-versus-1% voltage-noise scaling with identical underlying realization.
- Analytic source harmonic THD and Clock/Fcn expression equivalence at
  pre-event, event and post-event times, in all three phases.
- Synthetic log-validator tests: correct records accepted; missing voltage
  injection, changed noise replay, incorrect power feedback, and corrupted
  true-power monitoring correctly rejected.
- Synthetic analysis: known 50% harmonic THD and nonfundamental residual,
  known sqrt(2) W sensor RMSE, zero known tracking error/switching rate,
  and rejection of synthetic results by the native-results exporter.
- All 51 MATLAB files passed syntax parsing; two Python boundary tests pass.
- Package structure, source identity, fixture widths, MATLAB model-name
  lengths and custom-helper dependencies checked.

Not executed here; created/checked only by the supplied MATLAB start command:

- Native creation, compilation and execution of the original controller
  preflight and the new noisy-power-port preflight.
- Native compilation of the added SPS series controlled-voltage sources,
  Clock/Fcn blocks, sensor-noise replay and copied truth monitor.
- Actual converter runs: 7 cases x 2 control rates x 3 methods = 42 runs.
- Bit-exact full-plant binary-limit checks for all 14 scenario/rate pairs.
- Actual source waveform/polarity, feedback arithmetic and exact sensor
  noise replay verified from each native run's logs.
- Native figure rendering, observed THD/ripple performance, plant-step
  convergence, hardware behavior and statistical robustness.

The ZIP includes only local numerical/callback/structural reports with
simulink_executed=false. Successful native reports are generated after actual
MATLAB execution. Each native comparison stops if correctness checks fail;
there is no performance pass guarantee and no substitution of favorable data.

One default seed is an exploratory paired comparison, not statistical evidence.
Binary-limit equality establishes that the new interface can recover the
original controller; active ternary closed-loop performance is a separate test.
