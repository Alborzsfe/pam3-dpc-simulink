# Noise and distortion protocol

This is an experiment implementation, not evidence of a performance improvement.

## Paired controls and information access

For each scenario/seed/Fs, run the conventional converter, the new-table binary
limit, and the active ternary converter from the same original model and initial
conditions. The same finite noise array and the same physical source waveform
are used. Sensor-noise sampling is fixed at 200 kHz for both controller rates.
The source model SHA-256 is retained in configuration and checked in packaging.

The conventional P/Q feedback is the original calculator evaluated at measured
voltage and true measured current, plus independent additive P/Q sensor noise.
Voltage sensor noise reaches the angle/sector calculator as well. There is no
added current or DC sensor noise in this revision.

The ternary controller receives those SAME measured quantities. Its incremental
prediction is:

    power_hat_next(vector) = power_measured_now
                             + power_model_next(vector) - power_model_now

The zero-state target is the corresponding measured current power, and the
nonzero target follows the existing ternary law. This prevents recomputing clean
current power from v/i when testing noise injected after the power calculator.
The controller is not supplied with the injected-noise signal, true-power
monitor, case label, harmonic amplitudes, or future source values.

The original rotating fundamental-source/RL predictor is deliberately unchanged;
it is approximate under source harmonics, voltage measurement noise and ripple.
There is no assumption that the prediction guard guarantees closed-loop parity.

## Physical source

Let theta_k = omega*t + [0,-2*pi/3,2*pi/3]_k. The additive voltage is zero
before t_on and, afterwards,

    delta_v_k = V_peak * [h5*sin(5*theta_k) + h7*sin(7*theta_k)
                         + ripple*sin(2*pi*f_ripple*t)*sin(theta_k)]

The per-phase series sources add this voltage to the original ideal sources.
Five-times phase displacement gives a negative-sequence fifth harmonic;
seven-times displacement gives a positive-sequence seventh harmonic.
The amplitude ripple creates sidebands. With 300-Hz modulation and 50-Hz
fundamental these fall at 250 and 350 Hz, and overlap the fifth/seventh terms;
therefore do not infer total voltage THD by root-summing the three settings.
Actual physical voltage THD is measured and exported.

The analytic Clock/Fcn waveform avoids sample/hold distortion of the physical
source itself. Sensor noise, separately, is a finite sampled Gaussian record,
centered/normalized independently for each channel over its active interval.
All five channels use one local twister stream; global RNG state is restored.
For voltage-only tests, 1% and 3% use scaled versions of the same realization.

## Evaluation and checks

Physical instantaneous alpha/beta P/Q are recomputed by a separate copy of the
original power calculator for evaluation only. Checks also recompute those
powers independently from logged physical voltages/currents. Feedback and truth
are exported separately. Native checks verify the exact prescribed noise,
feedback arithmetic, and the actual physical grid voltage including polarity.

Current THD is the existing harmonic-only definition (orders 2..50). A separate
full sampled-band AC nonfundamental residual removes DC and a least-squares
fundamental sine/cosine fit. It includes noise, interharmonics and harmonic
energy within the logging bandwidth; it is not a standards-compliance metric.

Power ripple is not detrended beyond subtracting the window mean. Under grid
distortion it includes forced source-frequency power oscillations. Tracking,
DC regulation, switching and steady-window drift are reported alongside ripple.

Binary-limit verification requires zero gate mismatches at the 1-us plant rate
and relative physical/feedback differences below 1e-9. This is checked in EVERY
scenario and at EACH controller rate, not only with an ideal grid. The report
does not classify any active ternary method as equivalent based on this test.

Default one-seed results are exploratory; repeat with independent seeds for
uncertainty estimates. Do not select only favorable scenarios, seeds or metrics.

## Implementation documentation

- MathWorks From Workspace: https://www.mathworks.com/help/simulink/slref/fromworkspace.html
  Numeric [time,values] arrays; explicit sensor sample time; interpolation off;
  OutputAfterFinalValue = Holding final value.
- The power block and physical connection endpoints are taken directly from
  the supplied R2024b source SLX. Original sources and bridge topology are kept.
- The new MATLAB build script, including electrical source insertion, needs
  native MATLAB/Simulink execution; Octave tests cannot establish SPS compilation.
