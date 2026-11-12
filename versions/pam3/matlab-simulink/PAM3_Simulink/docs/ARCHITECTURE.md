# Bounded-memory streaming reconstruction

Source: supplied 19-page US11405248B2 PDF, figures 1-4 and columns 5-8.
`pam3_stream_core.sv` is a new synthesizable implementation of the documented
reconstruction, replacing the earlier simulation-only, whole-frame decoder.
No RTL, chip choice or exact adaptive update equation is supplied by the patent.

The design maintains finite state independent of total capture length. Each
clock may advance 1..LANES consecutive sample positions; the combinational
lane loop unrolls dependent operations in chronological order. Clock gating
through ready/valid freezes the algorithm when its output register is blocked.

| Stage | Information/state | Decision availability |
|---|---|---|
| DC and slope | Previous corrected ADC, four thresholds; optional 127-byte past ADC history | Current sample |
| Spike removal | Five original level samples with valid bits | Filtered index t-2 |
| Edge analysis | Last raw filtered edge index/direction; four pending edge slots | Second filter finalized after four later filtered positions |
| Must anchors | 32-bit ring marks for known midpoint indices | At most 13 input positions after the midpoint |
| Candidate clock | Fixed phase=6; free-run step=12; 32-entry filtered-level ring | Candidate index t-16 |
| Candidate filter | Four candidate and essential bits | Final output index t-20 |
| Symbol packer | At most 32+LANES two-bit symbols plus one output word | Full word or capture end |
| Host mux | One 128-bit registered record and round-robin bit | Next available host transfer |

Spike removal uses the **original** raw neighbours, preventing cascading edits.
A width-one or width-two isolated run is filled only when both neighbours agree.
The validity bits prevent invention of a neighbour beyond a capture boundary.
The output ring is 32 entries: its final read is 18 positions after a filtered
value was written, before ring reuse.

Must edges are opposite consecutive edge directions separated by at most 12
samples. For right edge r and preceding left edge l, midpoint is
`l+floor((r-l-1)/2)`. Spike lookahead is two samples; a midpoint precedes the
right edge by at most seven samples; the second edge filter takes four more.
Thus its anchor is available within 13 later input positions. The 16-position
candidate delay leaves margin, followed by the four-position candidate filter.

The first edge filter keeps a must edge, the first edge, or an edge at least
nine samples after its preceding raw edge. A current must edge cancels all
pending kept edges in its preceding four positions. Only must edges surviving
this second filter contribute midpoint anchors. Scanning candidate indices in
order ensures anchors reset the 12-sample schedule without transmitter timing.

The core has DATA, FLUSH and END_WAIT states. A terminal input schedules
20 virtual positions; validity guards prevent artificial ADC/level data from
affecting the finite-frame result. The terminal output transfer must be
accepted before per-frame state is reset. The capture ID then increments.
System reset aborts any in-flight capture and returns its ID to zero.

## Arithmetic adaptive option

ADAPTIVE=1 uses Q8 integer cluster means initialized to 60/127/194 codes.
Every completed 12-sample block, each class represented at least three times
updates its mean using `mu += floor((floor(sum*256/count)-mu)/8)`.
When both adjacent means differ by at least 12 codes, four thresholds follow
the documented 13/67, 32/67, 33/67 and 47/67 offsets from the middle mean.
Positive ratio products use floor division, then thresholds use
`floor((value_q8+128)/256)` and clamp to 1..254. This is half-up rounding,
not the previous float model's nearest-even rounding. Updates affect only
following real ADC samples, including later lanes in the same clock beat.

`reference/integer_model.py` models this integer rule independently. It uses
offline run boundaries and edge/candidate lists for the remaining decisions,
not the RTL ring buffers or pipeline logic. Fixed and literal-DC modes are also
compared to the earlier independent numerical model. When DC and adaptation
are both enabled, the DC maximum guard uses the current adaptive Plus value.

## Implementation tradeoffs

Eight lanes avoid an 800 MHz single-sample fabric clock, but replicate a long
combinational dependency chain. The DC min/max option scans 127 history values
per lane; the adaptive option includes constant divisions. These are
synthesizable, but no 100 MHz timing closure is implied. If the actual placed
design fails timing, restructure/pipeline the critical path, use appropriate
ADC parallelism and FPGA resources, or adjust the clock target. A timing fix
must retain the sample-order equivalence tests. The current portable version
prioritizes exact functional reconstruction and bounded state over an
unmeasured frequency or an invented board result.

Indices and scheduling state are 64 bits; avoid reaching counter wrap, reset
capture IDs if their 32-bit wrap would make host sessions ambiguous, and treat
reset/overflow as acquisition boundaries. The host record format retains
symbol order; direct core output retains exact sampling indices.
