# Reconstruction register: US 11,405,248 B2

Source: Prajeesh Prabhakar, Sudarshan Shenoy Mulki, Zakioddin Mahammad,
"FPGA based system for decoding PAM-3 signals", granted 2 August 2022.
The supplied 19-page PDF is included as source_patent.pdf. PDF pages below use
the actual PDF ordering; patent columns are the printed column labels.

## Disclosed versus reconstructed

| Element | Disclosed source | Implementation and uncertainty |
|---|---|---|
| Two acquisition/processing paths | Figure 1/2; columns 3-5 | Two independent streaming decoder instances; shared paired ADC acceptance; independent output decisions |
| Coupler, DVGA, ADC | Columns 3-5 | Input boundary is already-deserialized paired 8-bit ADC codes. Physical components are unselected and not implemented |
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
| USB / host protocol decoder | Figure 1; column 8 | 32-symbol packing, 128-bit channel/frame records, host Python parser. No actual USB controller, PCS descrambler or Ethernet frame decoder |
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

## Optional adaptive law (engineering assumption, integer hardware version)

This package uses the Q8 causal update in docs/ARCHITECTURE.md and
reference/integer_model.py. Initial means are 60/127/194 codes; each completed
12-sample block updates a class only when it contains at least three samples.
Means use floor division and signed floor shifting. The four ratios are
13/67, 32/67, 33/67 and 47/67, followed by half-up threshold rounding.
This differs in quantization from the previous simulation package's floating
nearest-even model. No exact update law is disclosed by the patent.
All four fixed/adaptive x DC on/off modes are now checked in RTL, with 1 and 8
samples per clock. Combined DC/adaptive uses the current Plus as the DC guard.

## Validation and hardware scope

- pam3_stream_core.sv: complete bounded-memory streaming core with exact indices.
- pam3_dual_core.sv: paired input acceptance, independent channel decisions.
- pam3_symbol_packer.sv and pam3_host_mux.sv: compact channel output records.
- pam3_analyzer_core.sv: integrated portable digital top.
- pam3_capture_fifo.sv: separately usable single-clock input buffer with explicit
  overflow/drop accounting; no physical CDC is implied.
- Independent numerical references evaluate finite captures using offline
  run/edge lists. They do not copy the RTL buffer/state organization.
- Actual Icarus execution and host parsing check all samples, filtered levels,
  sampling indices, symbols, terminal frames and ready/valid stability.
- Yosys structural results and mapped XC7 results are delivered separately.
- Mapped netlist simulation is functional, without physical timing delays.
- Vivado project and out-of-context scripts are supplied but not executed here.
- No bitstream, measured frequency, place/route, FPGA power, ADC electrical
  timing, calibrated directional coupler or physical USB path is supplied.

Synthetic stimulus is not an IEEE-compliant PCS stream or a measured cable.
Exact reconstruction equivalence is distinct from signal error performance.
The literal DC issue above is preserved explicitly; a successful equivalence
test does not resolve the patent's undisclosed register/equality semantics.
This package delivers the complete documented digital reconstruction, not
undisclosed company source code or a fully calibrated physical analyzer.
