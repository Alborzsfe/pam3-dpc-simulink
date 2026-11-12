# PAM-3 patent simulation and verification

Functional reconstruction of US 11,405,248 B2. Actual Monte Carlo/stress results,
complete Python model, independently checked SystemVerilog reference, and a
synthesizable acquisition front end. See docs/ASSUMPTIONS.md before using results
in a paper. These are simulated PAM-3 results, not measurements of the patented
commercial product or a certified Ethernet PHY.

## Open results without installing anything

Open `PAM3_Results.html` in any modern browser. It contains its own data and
charts; no internet connection is required. Waveform controls display saved
full-resolution trace windows from the actual run. `PAM3_Simulation_Report.pdf`
is the English technical report. All machine-readable results are under results/.

## Run an interactive new simulation

Python 3.10+ is required. On Windows, double-click `START_WINDOWS.bat`, which
creates a private .venv, installs requirements and starts the local interface.
Installation needs internet the first time; the simulation itself uses no API.
Or use a terminal in this directory:

```sh
python -m pip install -r requirements.txt
python app.py
```

Open http://127.0.0.1:8765. Change SNR, gain, DC, clock drift and jitter; press
the new-simulation button. The server binds only to this computer. Results can
be downloaded as JSON. Ctrl+C stops it.

## Reproduce the complete delivered numerical run

```sh
python -m unittest discover -s tests -v
python run_simulation.py --symbols 4096 --repetitions 5
python make_report.py
```

The first numerical run takes roughly tens of seconds here; runtime depends on
your computer. `REPRODUCE_WINDOWS.bat` performs these commands after dependency
setup. New reports regenerate from new CSV/JSON, not stored chart substitutes.

## HDL validation

Install Icarus Verilog, ensure `iverilog` and `vvp` are on PATH, then:

```sh
python verify_hdl.py
```

For installed Vivado, run from the package root after generating vectors:

```sh
vivado -mode batch -source rtl/vivado_sim.tcl
```

The delivered HDL was executed with Icarus Verilog 12.0. The Vivado Tcl script
is an unexecuted convenience script; neither Vivado nor FPGA-board validation
was performed. `results/hdl/dual_channel.vcd` can be viewed in GTKWave/Vivado.

## Use measured ADC data

Prepare a CSV with `master` and/or `slave` headers and unsigned integer ADC
codes 0..255. The input is assumed already deserialized and sampled near
12 samples/symbol. Example:

```sh
python decode_csv.py measured.csv --out decoded
```

Add `--dc` for the literal printed DC equation or `--adaptive` for the inferred
update law. Without a known transmitted reference, no SER is reported.

## Included variants

- `patent_fixed_bypass`: disclosed four thresholds, DC bypass and reconstructed
  spike/timing logic; best-defined working reference for this package.
- `patent_literal_dc`: same reconstruction, literal DC equation with documented
  assumed guard value. Reveals a conditional DC/slicing conflict.
- `inferred_adaptive_bypass`: causal decision-directed update law chosen here;
  the patent does not disclose this exact law.
- `two_threshold_fixed_clock`: simple fixed comparator/clock baseline; not
  a recreation of another research paper and not given oracle TX timing.

Metrics include missing/duplicate symbols; low error rates must not be read
as field reliability. The report includes cases where the simpler baseline wins.

Validation: 17 Python/model/API tests and 12 HDL scenarios passed. A DOM
integration test checked UI controls and applying real API results. It mocked
Canvas drawing calls; native Chromium rendering was blocked by the execution
environment. No actual browser screenshot is claimed. The PDF was rendered
and visually inspected. `results/dom_validation.json` records this distinction.

Files in results/hdl include saved comparison vectors/logs; the VCD represents
a 100 MHz testbench clock and is not evidence of 800 MS/s throughput. The
SystemVerilog full decoder is frame-based and simulation-only. The separate
DC/slope front end is written for synthesis but has no synthesis/timing result.
