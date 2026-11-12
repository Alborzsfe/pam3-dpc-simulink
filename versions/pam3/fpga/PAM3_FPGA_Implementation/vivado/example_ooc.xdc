# EXAMPLE abstract digital-interface constraints only. Not ADC LVDS timing.
# Eight valid samples each 10 ns gives 800 MS/s as an INPUT RATE TARGET.
# Timing closure is not established by this constraint or by Yosys mapping.
create_clock -name core_clk -period 10.000 [get_ports clk]
set_input_delay 2.000 -clock core_clk [remove_from_collection [all_inputs] [get_ports clk]]
set_output_delay 2.000 -clock core_clk [all_outputs]
# No PACKAGE_PIN / IOSTANDARD: these require the actual board and PHY design.
