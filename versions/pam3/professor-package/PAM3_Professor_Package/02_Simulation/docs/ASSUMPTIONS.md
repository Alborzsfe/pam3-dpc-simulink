# Reconstruction register: US 11,405,248 B2

Source: Prajeesh Prabhakar, Sudarshan Shenoy Mulki, Zakioddin Mahammad,
"FPGA based system for decoding PAM-3 signals", granted 2 August 2022.
The supplied 19-page PDF is included as source_patent.pdf. PDF pages below use
the actual PDF ordering; patent columns are the printed column labels.

## Disclosed versus reconstructed

| Element | Disclosed source | Implementation and uncertainty |
|---|---|---|
| Two acquisition/processing paths | Figure 1/2; columns 3-5 | Independent synthetic master and slave channels; independent random seeds and different clock phase |
| Coupler, DVGA, ADC | Columns 3-5 | Behavioural leakage, gain, clipping, rounding and 8-bit code model; no selected chip or transistor-level model |
| 800 MS/s / approximately 12 samples per symbol | Column 5; claim 3 | 1.25 ns per sample; 12 samples per ideal symbol, approximately 66.667 MBd. Patent writes 66.66 Mbps, a unit imprecision for symbol rate |
| Deserialization and input buffering | Figure 3; column 5 | Model receives already-deserialized ADC samples; no vendor ISERDES or physical LVDS timing implemented |
| DC window | Column 5 | Causal window including current and preceding 127 samples; incomplete startup window uses available history |
| DC equation | Column 6 | Literal MAX/MIN condition and strict <255 bound; widened arithmetic. Default guard Minus_Maximum_Threshold=80 is assumed because no numeric value is disclosed |
| DC target | Column 6 equation | Minus_Threshold=95 literal interpretation. Separate anchor=60/80 sensitivity variants are labelled engineering changes |
| Four level thresholds | Column 6; Figure 4E | 140/95/160/80 exactly as printed; default nominal ADC levels 60/127/194 are assumed |
| Falling-slope rule | Column 6 | Mirrored interpretation of the stated analogous negative-slope logic; x<95 means -1, 95<x<160 means zero; exact equality preserves previous level |
| Constant sample | Column 6 | Hold previous decoded level; initial level zero |
| Spike filter | Figure 4F; column 7 | Fill an isolated run of at most two samples only if both original adjacent runs agree; keep three-sample real pulse of Figure 4G. This is an explicit reconstruction, not supplied RTL |
| Must transition | Figure 2/4G; column 7 | Opposite consecutive edge directions separated by <=12 samples; midpoint of intervening plateau. Figure 4G has +1 -> zero -> +1, so a sign-of-level-only rule would miss that illustrated pulse. Text is ambiguous; this choice is documented |
| Integer midpoint | Figure 4G | floor((left_edge+right_edge-1)/2) for interval [left_edge,right_edge), avoiding right boundary; no rounding convention supplied |
| First edge filter | Column 7; claim 10 | Keep must edges or distance >=9 from preceding raw edge. Raw versus previously retained edge is not explicitly resolved by patent |
| Second edge filter | Column 7; claim 11 | Drop an edge when a must edge appears within the next four samples |
| Sampling schedule | Columns 7-8; claims 16-18 | Free-run in steps of 12, restart at a retained must midpoint; initial sample phase=6 is a receiver parameter, never fitted using TX labels |
| Sampling-point filter | Column 8; claim 14/19 | Keep must candidates; discard non-must candidate with another candidate within four following samples |
| Dynamic thresholds | Columns 6-7; claim 7 | Optional inferred causal update law below; never described as the company's exact implementation |
| USB / host protocol decoder | Figure 1; column 8 | Decoded-symbol export represents host output. No actual USB controller, PCS descrambler or Ethernet frame decoder |
| 1000BASE-T1 | Column 8; claim 13 | Patent claims applicability but gives no complete gigabit design; this package implements only the 100BASE-T1-rate functional example |

## Literal DC issue

When correction is active, y = x - MIN + 95. Since the causal window includes x,
x >= MIN and thus y >= 95. The reconstructed strict falling rule needs y <95
to identify -1. These conditions cannot coincide. Correction bypass, disabled
guard, clipping guard or holding a previously identified level can change the
behaviour; the conflict is conditional, not a universal claim that the product
cannot work. The PDF does not resolve whether its DC target and slicing
threshold names refer to different register values or whether equality handling
differs. The main fixed method therefore uses the patent's explicitly permitted
DC bypass. The literal formula is retained as a separate tested method.

## Optional adaptive law (engineering assumption)

Initial cluster means: (low, middle, high) = (60,127,194) ADC codes. At the end
of each non-overlapping 12-sample block, classify with the current threshold
values and accumulate each decoded class's mean. For classes with >=3 samples:
mu_new = mu_old + (block_mean - mu_old)/8. Update thresholds only when both
estimated adjacent class gaps are >=12 codes:

- Plus = middle + 13/67 * (high-middle)
- Minus = middle - 32/67 * (middle-low)
- ZeroPlus = middle + 33/67 * (high-middle)
- ZeroMinus = middle - 47/67 * (middle-low)

Round to nearest integer (NumPy nearest-even convention) and clamp to 1..254.
Only completed blocks affect future samples. This decision-directed law uses
no TX labels, measured SNR, true gain, or true DC offset. Incorrect decisions can
reinforce incorrect means; performance is not uniformly better than fixed slicing.
This variant has Python validation only; fixed/DC modes are cross-checked in HDL.

## Signal and statistical scope

Symbols are synthetic random/structured PAM-3. They are not an IEEE-compliant
100BASE-T1 PCS stream. A first-order sample-domain channel models finite edges;
echo is a delayed weighted tap; reverse-channel leakage is an independent
PAM-3 contributor. These do not reproduce a measured directional coupler or
automotive cable. SNR is relative to nominal transmitted zero-mean symbol power
67^2 E[s^2], before gain, echo and clipping. Therefore changing gain also changes
effective received SNR. ADC quantization is round-to-nearest, saturating 0..255.

True TX timing is supplied only to the evaluator. Each original TX interval
passes only if exactly one decoded output lies inside it and its value is right.
Missing and duplicate symbols count as failures. No edit-distance matching,
best-phase fitting, or discarded internal failures. First 32 and last 8 symbols
are excluded by a fixed policy declared before analysis. This metric is stricter
than amplitude-only SER; both missing and extra counts are also given.

Five independent seeds and two receiver phases are used per SNR. Wilson bounds
are descriptive pooled-symbol bounds; errors can be burst-correlated, so these
are not a proof of independent-binomial uncertainty. Run min/max/SD are supplied.
Zero observed errors does not establish zero probability of error.

## HDL and hardware scope

- `pam3_reference.sv`: complete frame-based behavioural model, simulation only.
- `pam3_frontend.sv`: synthesizable sliding-window DC and slope/level logic,
  checked with input-valid bubbles. Its wide comparator reduction is intentionally
  readable and has no demonstrated 800 MS/s timing closure.
- `tb_dual.sv`: two channel stimulus, stage comparisons, output counts, exact
  sampling indices and values, and optional VCD.
- Icarus Verilog execution is documented in results/hdl/validation.json.
- Vivado invocation script is supplied but was not executed here.
- No FPGA board, synthesis, placement/routing, LVDS electrical model, real-time
  capture, resource utilization, power or USB throughput was measured.

This is a reproducible functional reconstruction and hardware-oriented
verification package, not an exact copy of undisclosed vendor RTL or a
fully-validated automotive Ethernet analyzer.
