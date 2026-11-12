# Run from package root: vivado -mode batch -source rtl/vivado_sim.tcl
# A functional simulation; no board or implementation claim.
file mkdir results/vivado
exec xvlog -sv rtl/pam3_frontend.sv rtl/pam3_reference.sv rtl/tb_dual.sv
exec xelab tb_dual -s pam3_sim
set n 9242
# Exact sample count should be read from current input; avoid hardcoded stale vectors.
set f [open results/hdl/clean_input.txt r]
set n [llength [split [string trim [read $f]] "\n"]]
close $f
exec xsim pam3_sim -runall -testplusarg "N=$n" -testplusarg "DC=0" \
  -testplusarg "INPUT=results/hdl/clean_input.txt" \
  -testplusarg "STAGES=results/hdl/clean_bypass_stages.txt" \
  -testplusarg "SYMA=results/hdl/clean_bypass_a.txt" \
  -testplusarg "SYMB=results/hdl/clean_bypass_b.txt"
