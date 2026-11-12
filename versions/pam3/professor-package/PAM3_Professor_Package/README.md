# PAM3 patent reconstruction — professor review copy

Open `01_Results/index.html` in a browser. Windows users can double-click
`START_WINDOWS.bat`; viewing recorded results requires no Python installation.
The five PNGs in `01_Results/screenshots` are screenshot-style result views rendered from the included experiment data.
They are not IDE, Vivado, board, or live-instrument screenshots. The header
labels recorded data; the local HTML report presents the same evidence.

## Contents
- `01_Results`: five review views, figures, compact figure data and PNGs.
- `02_Simulation`: original Python receiver/channel, experiment runner, recorded
  quantitative results and the two traces used in the review figures.
- `03_FPGA`: original streaming SystemVerilog, independent Q8 reference,
  testbenches, verification tools, mapped Verilog, evidence and source patent.

## Reproduce (Python 3.12 was used)
From the package root, install `python -m pip install -r requirements.txt`.
Then run the following from `02_Simulation`:
```
python -m unittest discover -s tests -p test_model.py
python run_simulation.py --out results_reproduced --symbols 4096 --repetitions 5
```
The result folder is intentionally separate so original evidence is preserved.
The full run regenerates the omitted traces. The adaptive Python experiments
use the original floating-point update, while FPGA tests use the documented Q8
integer update. These are separate references and are labelled in the report.

From `03_FPGA`, with Icarus Verilog installed:
```
python verify_hdl.py --quick
python verify_interfaces.py
python host_decode.py results/example_host_records.bin --csv decoded.csv --summary decoded.json
```
For the original full eight-setting suite, omit `--quick`. The scripts write to
`results`; make a copy first if preserving original saved RTL evidence matters.
For synthesis, install Yosys with its Xilinx library:
```
python run_synthesis.py --lanes 1
python run_synthesis.py --lanes 8
python check_structure.py
python verify_netlist.py --lanes 1 --cells /usr/share/yosys/xilinx/cells_sim.v
python verify_netlist.py --lanes 8 --cells /usr/share/yosys/xilinx/cells_sim.v
```
Use the actual `cells_sim.v` location on your system. Vivado project/OOC scripts
are in `03_FPGA/vivado`; they were not executed in the delivered experiments.

## Scope
This is a documented digital reconstruction, not the patent holder's source.
The physical coupler/DVGA/ADC interface, CDC, transport hardware, Ethernet PCS,
board bitstream, place/route timing and real-cable measurements are not included.
No measured 100 MHz or 800 MS/s performance is claimed. RTL equivalence and
mapped functional simulation do not establish noisy-channel accuracy.
The literal DC ambiguity and inferred adaptive law are explained in
`03_FPGA/docs/PATENT_ASSUMPTIONS.md`.

## Packaging changes
Removed disposable simulator binaries, caches, long input/trace/VCD dumps,
EDIF copies of mapped Verilog, duplicate PDFs/HTMLs, obsolete whole-frame HDL,
UI automation checks and old delivery manifests. Core algorithms are unchanged.
Only two illustrative NPZ traces are retained; all numeric experiment rows are
included. A single source patent is retained under `03_FPGA/docs`.
`SHA256SUMS.txt` covers the final review copy. Screenshot/test provenance is in
`REVIEW_VALIDATION.json` after final checking.

To regenerate the review figures and screenshot-style images from the saved
evidence, run `python tools/regenerate_review.py` and then
`python tools/render_result_images.py` from the package root.
