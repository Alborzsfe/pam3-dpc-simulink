# Digital interfaces and integration contract

All RTL uses one `clk`, active-high synchronous `rst`, and rising-edge
ready/valid transfers. Reset clears algorithm history, buffers, frame numbering,
and sticky errors. An asserted `valid` must hold its payload until a transfer.

## ADC boundary: `pam3_analyzer_core`

| Port | Meaning |
|---|---|
| `s_valid / s_ready` | Paired-channel beat transfers only when both are high |
| `s_adc_a`, `s_adc_b` | `8*LANES` bits each; earliest sample is bits 7:0, next is 15:8 |
| `s_count` | Number of contiguous valid samples: 1..LANES; zero only for an empty terminal beat |
| `s_last` | End this acquisition interval after the valid samples in this beat |
| `m_valid / m_ready` | 128-bit host record handshake |
| `m_data` | Record format below |
| `m_last` | Same value as record bit 72; terminates this channel's interval |
| `protocol_error[1:0]` | Sticky invalid input-count flags, channel A and B |
| `protocol_error[3:2]` | Sticky symbol-packer frame-consistency flags, A and B |

Validated build choices: `LANES=1` and `LANES=8`, `DC_ENABLE=0/1`,
`ADAPTIVE=0/1`. Defaults are 8 lanes, DC bypass, fixed thresholds.

`s_last` denotes a **capture interval**, not an Ethernet packet. It resets all
receiver history for the next interval after tail processing completes. The
channels share these boundaries and sample counts; their decisions, points,
and outputs remain independent. Without `s_last`, the algorithm runs
continuously with bounded memory. Finalizing a capture adds 20 virtual sample
steps and temporarily deasserts `s_ready`; those steps do not update the ADC,
DC or adaptive histories. Empty intervals still produce a terminal host record
for each channel. An ADC PHY that cannot pause needs an acquisition buffer and
adequate long-term host bandwidth. This handshake boundary itself can pause.

Both channels accept a beat together, preventing one channel from advancing
twice while the other is blocked. Independent channel output stalls may delay
the next paired input transfer. The host mux preserves order within each
channel, with round-robin arbitration when both channels have a record.

## Host record: 128 bits / 16 bytes

| Bits | Width | Field |
|---|---:|---|
| 63:0 | 64 | Up to 32 packed PAM3 symbols; oldest at bits 1:0 |
| 70:64 | 7 | Valid symbol count, 0..32 |
| 71 | 1 | Channel: 0=A/master, 1=B/slave |
| 72 | 1 | Last record of this channel interval |
| 104:73 | 32 | Per-channel interval ID, initially zero |
| 127:105 | 23 | Reserved, all zero |

Symbol coding: `11=-1`, `00=0`, `01=+1`; `10` is invalid. Unused payload
bits are zero. A zero-count record is legal only at an interval end. Full
records contain 32 symbols; a terminal record contains 0..32 symbols.
Serialization on disk uses **16 little-endian bytes per record**. A transport
adapter must preserve those bytes and must not insert its own framing into
the supplied parser's input file. The independent core exposes exact 64-bit
sample indices; the compact host records retain ordinal symbol order only.
Use `pam3_dual_core` rather than the packed top when sample indices are needed.

Example parsing:

```bash
python3 host_decode.py results/example_host_records.bin \
  --csv results/example_decoded_symbols.csv \
  --summary results/example_decoded_summary.json
```

## Core output and latency

`pam3_stream_core` produces `m_mask[LANES]`, signed two-bit symbols, one
64-bit index per output lane, frame ID, and last. Lane order is chronological;
a mask may be sparse. An empty terminal transfer is intentional. Output fields
remain stable while `m_valid && !m_ready`.

For a selected index `q`, the decision is produced while processing virtual
tick `q+20`, so 20 later sample positions must be available. This is an
algorithmic lookahead measured in samples, not a measured physical delay.
Eight-lane unrolling groups those positions in clock beats; stalls add wall
time. Packing a word also waits for up to 32 symbols or a terminal interval.

## Capture FIFO

`pam3_capture_fifo` is a separately usable, single-clock buffer. It is not
silently inserted into the processing top. Pack a paired input beat as
`{s_last,s_count,s_adc_b,s_adc_a}`; with 8 lanes this is 133 bits.
Depth is `2**LOG_DEPTH` beats. Defaults: WIDTH=133, LOG_DEPTH=8, depth=256,
holding at most 2,048 sample positions per channel (2.56 us at a hypothetical
800 MS/s arrival rate). This is a buffer-capacity calculation, not a timing
result. Simultaneous pop/push is accepted even when initially full.

`overflow` is sticky and `dropped_beats` saturates at 0xffffffff. Any overflow
invalidates the affected acquisition: sample continuity and frame boundaries
may have been lost. Reset/restart the capture rather than treating its decoded
symbols as complete. A finite FIFO cannot fix a sustained bandwidth mismatch.
This implementation has an asynchronous memory read and may map to registers
or distributed RAM; it is not promised to use BRAM. A multi-clock ADC interface
requires a verified asynchronous FIFO instead of this module.

## Physical integration remaining

Choose the actual directional coupler, DVGA, ADC, board, and transport first.
Then implement the ADC vendor's clocking/deserialization and CDC, board pin
constraints and I/O timing, capture-control/overflow handling, and the chosen
USB/PCIe/Ethernet/DMA transport adapter. Analog calibration must map measured
PAM3 amplitudes to suitable 8-bit codes. The host parser does not implement the
100BASE-T1 PCS descrambler or decode Ethernet frames. Those are separate
protocol modules, absent from the patent's detailed algorithm disclosure.

For nominal 66.667 MBd and two channels, two-bit symbol payload is about
33.333 MB/s. The supplied 128-bit records double that to about 66.667 MB/s
before transport overhead, assuming full 32-symbol records and correct symbol
rate. Short intervals add headers. The 800 MS/s two-channel 8-bit raw boundary
corresponds to 1.6 GB/s before processing. These are arithmetic budgets only.
