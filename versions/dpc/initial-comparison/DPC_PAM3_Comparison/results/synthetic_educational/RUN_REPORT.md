# Identical-input DPC / PAM3 comparison

- Input provenance: **synthetic_educational**.
- Same error samples supplied to all comparison routes: 1.
- Actual comparison Simulink replay executed: 0.
- Closed-loop gate table modified: 0.
- Samples per channel: 4001; sample time: 5e-06 s.
- Patent mode: 0 (0 fixed; 1 Q8 engineering update). DC correction bypassed.
- Neutral release/activation ratio: 0.5.

| Channel | Method | Decision changes | Neutral % | Outer-band sign mismatch % | Mean response us | Missed episodes |
|---|---|---:|---:|---:|---:|---:|
| P | binary_replay | 7 | 0.000 | 0.000 | 0.000 | 0 |
| P | control_ternary | 14 | 54.639 | 0.000 | 0.000 | 0 |
| P | patent_raw | 368 | 61.840 | 14.891 | 0.185 | 0 |
| P | patent_filtered_causal | 270 | 61.965 | 16.174 | 7.292 | 3 |
| Q | binary_replay | 2 | 0.000 | 0.000 | 0.000 | 0 |
| Q | control_ternary | 6 | 54.989 | 0.000 | 0.000 | 0 |
| Q | patent_raw | 462 | 63.866 | 19.543 | 0.000 | 0 |
| Q | patent_filtered_causal | 292 | 63.366 | 18.708 | 15.000 | 0 |

## Calibration and original capture diagnostics

P: ADC=clip(round(117.5 + 22.5*error),0,255). Clipped samples: 0.0000%. Quantization half-LSB: 0.0222222222222 model error units.

Initial thresholds [plus, minus, zero-plus, zero-minus] in error units: [1 -1 1.88889 -1.66667].

Q: ADC=clip(round(117.5 + 22.5*error),0,255). Clipped samples: 0.0000%. Quantization half-LSB: 0.0222222222222 model error units.

Initial thresholds [plus, minus, zero-plus, zero-minus] in error units: [1 -1 1.88889 -1.66667].

## Interpretation

Decision changes are detector output transitions, not measured semiconductor switching. The binary output is mapped from OFF/ON to -1/+1 only for sign diagnostics; native 0/1 is exported too.

The causal patent filter has 2-sample latency. Symbol outputs have 20-sample latency and are sparse; they are not treated as a sample-rate converter control output.

Outer-band sign mismatch and response latency are rule-based diagnostics, not communication SER. A neutral state or fewer decisions alone does not establish better P/Q tracking, ripple, THD, or efficiency. Those require a redesigned switching table and separate closed-loop simulations.
