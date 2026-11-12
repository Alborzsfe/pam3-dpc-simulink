# Revision 2: native binary Relay threshold equality

The user executed revision 1 in actual MATLAB/Simulink R2024b. Its
numerical checks passed, but native preflight stopped at the Relay check.
The user then extracted the following native observations from the saved
failed simulation (one-based indices; the two-channel input has 431 samples):

| Channel | Sample | Input | Native output | Revision 1 reference |
|---|---:|---:|---:|---:|
| P | 43 | +1 | 1 | 0 |
| Q | 39 | -1 | 0 | 1 |
| Q | 44 | +1 | 1 | 0 |
| Q | 50 | -1 | 0 | 1 |

The independent Python reference incorrectly used strict comparisons for
the native binary Relay. Inclusive comparisons (>= +1, <= -1) reproduce
exactly these four differences and no others in the original input stream.
The same regression is checked for both fixture sampling rates. This is a
correction to the oracle, not relaxation or removal of the native assertion.

Changes:

- Correct the independent binary reference and regenerate the complete MAT
  fixtures, including dependent original/proposed gate outputs and audits.
- Independently recompute binary reference history in the MATLAB numerical
  test; check both channels for every sample, including threshold equality.
- Add Python tests for the four observed discrepancies, full binary streams,
  equality, and adjacent floating-point values on either side of thresholds.
- Log/check both native input error channels and print the first Relay
  discrepancy with channel, sampling rate, mode, sample, time, and values.
- Correct the documentation that incorrectly equated the proposed ternary
  classifier's strict outer comparisons with native binary Relay semantics.

Unchanged: original SLX, original native Relays, switching table, proposed
ternary classifier, predictor, controller/table S-functions, converter model
builder, physical parameters, THD/ripple metrics, exact native assertions,
and full-plant binary-limit requirement.

Local verification uses Python and Octave, including callback test doubles.
Revision 2 has NOT been executed in native MATLAB/Simulink here. The user's
four observations validate the boundary diagnosis, not the whole new package
or converter performance. No native PASS or performance result is prefilled.

Extract this ZIP into a new folder, use it as MATLAB Current Folder, and run:

```matlab
clear functions
START_DPC_TERNARY
```

The startup banner must contain `revision 2`. The workflow still stops on
any remaining native discrepancy before proceeding to converter comparison.
