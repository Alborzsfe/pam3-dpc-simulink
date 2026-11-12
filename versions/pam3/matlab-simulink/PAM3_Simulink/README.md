# US11405248B2 — MATLAB/Simulink digital reconstruction

Read README_FA.md for Persian instructions. Extract the entire project and run
`START_PAM3` from MATLAB in this folder. It checks the .m implementation, builds
native models via official APIs, runs the demo, and compares sample-rate traces.

The delivered `.slx` containers are structurally authored against a native R2022a
schema. They have not been opened/compiled in MATLAB in this environment. The
included `build_pam3_models` script is the authoritative native-authoring route.
It regenerates both `.slx` files; MATLAB/Simulink execution is not claimed until
the runtime-generated validation passes. This is a normal-mode simulation;
no MATLAB Coder, HDL Coder, Simscape or Python runtime is required by the model.

## Model boundary

Paired, already-deserialized ADC codes -> two independent receivers -> packed
128-bit host records. `generate_pam3_input` supplies a behavioural channel,
directional leakage, amplifier gain, noise and quantization. It is not a physical
front-end circuit or an IEEE PCS encoder. The example 800 MS/s clock scales
simulation time; this is not a measured CPU/FPGA throughput or ADC I/O result.

Each receiver has 249 double-valued DWork state slots, independent of capture
length. `pam3_step` is pure: Outputs can be reevaluated without modifying state;
Update commits its next state. Initial conditions and explicit reset are handled.
Normal-mode Level-2 MATLAB S-Functions retain their states in DWork, not shared
persistent receiver variables. The persistent layout object is immutable.

## Acquisition commands

0 = idle (no sample-index advance); 1 = accept real ADC; 2 = tail flush;
3 = reset session. Send exactly 20 command-2 ticks after a finite capture.
Invalid flush positions never update ADC/DC/adaptive histories. A new capture
requires a reset; host frame numbering restarts at zero for each session.
There is no host backpressure in this Simulink harness. A transport buffer and
clock-domain adapter are physical integration tasks.

## Decoder trace (18 scalar channels)

1 symbol valid; 2 symbol; 3 zero-based chosen index; 4 corrected ADC;
5 raw level; 6 raw valid; 7 filtered level; 8 filtered valid;
9 zero-based filtered index; 10..13 Plus/Minus/ZeroPlus/ZeroMinus thresholds;
14 edge detected; 15 must edge; 16 candidate; 17 essential candidate;
18 end of capture. Rows with invalid flags are not data samples.

Packer output: 1..2 channel packet-valid flags, 3..18 master bytes,
19..34 slave bytes. Records preserve symbol order, channel, count and end flag.
Byte format is the original FPGA little-endian 128-bit layout; sample indices
are retained in decoder traces/CSV, not in the compact packet.

## Reference and checks

`python_reference` is the independent offline model delivered previously. It
uses run boundaries/edge lists, not the new MATLAB pipeline. `data/golden_cases.mat`
contains 600 channel captures, five supported settings and their stage/output
references. `tools/generate_fixtures.py` regenerates them with NumPy/SciPy.
Fixed and Q8 combined modes mirror the documented RTL; float/DC-off mirrors the
original NumPy nearest-even implementation. The float/DC-on combination is
intentionally unsupported because the old float DC prepass used a different
maximum guard from the Q8 sample-causal combined mode.

Run `validate_matlab(false)` for the full language-level suite and
`validate_simulink` for actual S-Function/solver execution against independent
fixtures. `run_pam3_snr_tests(true)` performs fresh end-to-end noisy-channel
experiments in Simulink. Using `false` executes just the .m receiver.
Do not describe a language-level or structural pass as a Simulink execution.
Do not describe oracle equivalence as error-free reception against TX truth.

## Disclosed and inferred choices

The source patent and assumption register are in docs. The original RTL
architecture document is context, not an assertion that RTL is executed here.
The literal DC conflict is retained. The adaptive update, spike rule, opposite
edge-direction interpretation, midpoint rounding and initial phase are labelled
reconstructions. This package is not the patent holder's undisclosed source.
The optional adaptive block has its own quantization mode, not a vendor law.

The DPC power-converter model is not modified or connected by this project.
First validate this standalone PAM3 transfer before adapting it to power errors.

## Delivery-time numerical verification

The actual .m files were executed in GNU Octave 8.4.0. The full independent
fixture suite passed: 600 captures, 346,100 sample checks and 30,575 symbols.
Packet bytes, empty terminal records and source/evaluation functions also
passed. This is language-level execution, not MATLAB or Simulink execution.
`results/core_demo_result.mat`, `core_decoded_symbols.csv` and
`core_host_records.bin` contain actual GNU Octave outputs, explicitly labelled.
The demo contains capture padding; its output count is not an Ethernet packet
length or necessarily the transmitted symbol count.
