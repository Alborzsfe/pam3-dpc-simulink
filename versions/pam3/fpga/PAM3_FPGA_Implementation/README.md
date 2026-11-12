# US11405248B2: portable streaming digital implementation

See **README_FA.md** for the Persian handover and **docs/INTERFACES.md** for
the integration contract. This is complete RTL for the documented digital
reconstruction from paired deserialized 8-bit ADC samples to packed PAM3 host
records. Physical ADC/coupler/DVGA/USB hardware, board pins, Ethernet PCS,
bitstream and 800 MS/s timing closure are outside the implemented boundary.

## Reproduce

Python 3.12, NumPy/SciPy; Icarus Verilog 12.0; Yosys 0.33 with XC7 libraries
were used. Compatible newer tools may be used, but are not claimed tested.
Run from this directory:

```bash
python3 -m pip install -r requirements.txt
python3 verify_hdl.py
python3 verify_interfaces.py
python3 check_structure.py --yosys yosys
python3 run_synthesis.py --yosys yosys --lanes 1
python3 run_synthesis.py --yosys yosys --lanes 8
python3 verify_netlist.py --lanes 1 --cells /usr/share/yosys/xilinx/cells_sim.v
python3 verify_netlist.py --lanes 8 --cells /usr/share/yosys/xilinx/cells_sim.v
python3 host_decode.py results/example_host_records.bin
```

`verify_hdl.py --quick` runs the small boundary-focused suite; the delivered
validation comes from the full suite. Optional `--iverilog`, `--vvp`, `--base`
arguments support installations outside PATH. The synthesis flow omits the
optional SAT resource-sharing optimization and preserves the explicit data
and control-state encodings. Netlist simulations have no physical timing.

## Defaults

Top: `pam3_analyzer_core`. LANES=8, DC_ENABLE=0, ADAPTIVE=0. Input is oldest
sample first, little-endian byte lanes. Output is 128-bit records, up to
32 two-bit symbols per record, with channel ID, capture ID and terminal flag.
Use `pam3_dual_core` to retain exact sample indices. The standalone capture
FIFO is single-clock and flags dropped input beats explicitly.

`reference/integer_model.py` uses a causal Q8 adaptive front end and independent
offline run/edge/candidate lists for the oracle. No TX timing is fed to the
decoder. Exact equivalence does not establish real-channel error performance.
The literal patent DC equation's slicing ambiguity is preserved and disclosed.

## Vivado

```bash
vivado -mode batch -source vivado/create_project.tcl -tclargs xc7a200tfbg484-2 8 0 0
vivado -mode batch -source vivado/synth_ooc.tcl -tclargs xc7a200tfbg484-2 8 0 0 1
```

The part is an example. The 10 ns constraint is an example target, not proof
of timing. Replace them using actual hardware requirements. Vivado was not
executed in this environment. No pin assignment or bitstream is fabricated.

## Reports

`results/verification/validation.json`: all 16 RTL executions and comparisons.
`results/interfaces/validation.json`: FIFO, reset, invalid-count and host tests.
`results/structure/validation.json`: all options plus capture FIFO structural checks.
`results/synthesis/*/summary.json`: actual XC7 technology mapping counts.
`results/post_synthesis/*/validation.json`: mapped-netlist functional tests.
PDF and Persian HTML handover summarize these exact machine-readable results.

The ZIP omits simulator binaries, Python caches and large disposable trace/input
copies. Test sources deterministically regenerate them. It retains the example
capture, validation results, simulator logs, mapped Verilog/EDIF, source patent,
RTL, references, host tool and Vivado scripts. `SHA256SUMS.txt` covers included
files for handover integrity; it is not a signature or a safety certification.
