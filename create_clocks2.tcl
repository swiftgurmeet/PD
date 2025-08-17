# Primary clock definition
# Define a 100MHz clock with 50% duty cycle on the input port 'CLK_IN'
create_clock -period 10.000 -name sys_clk -waveform {0.000 5.000} [get_ports CLK_IN]

# Generated clock 1 (frequency division)
# Create a 50MHz clock (sys_clk / 2) on the output pin of a register 'DIVIDER_REG/Q'
create_generated_clock -name clk_div2 -source [get_pins DIVIDER_REG/C] -divide_by 2 [get_pins DIVIDER_REG/Q]

# Generated clock 2 (frequency multiplication and phase shift)
# Create a 200MHz clock (sys_clk * 2) with a 2.5ns phase shift (offset by 2.5ns from sys_clk)
# derived from the output pin 'PLL_OUT' of a PLL instance.
create_generated_clock -name clk_2x_shifted -source [get_pins PLL_INST/CLK_OUT] -multiply_by 2 -edge_shift {2.5 7.5 12.5} [get_pins PLL_INST/CLK_OUT]

# Generated clock 3 (complex waveform using -edges)
# Create a generated clock with a custom waveform derived from 'sys_clk'.
# This clock rises at the 1st edge of sys_clk, falls at the 5th edge, and rises again at the 7th edge.
# This results in a non-standard duty cycle and period based on the parent clock edges.
create_generated_clock -name custom_clk -source [get_ports CLK_IN] -edges {1 5 7} [get_pins CUSTOM_CLK_GEN/CLK_OUT]

# Virtual clock for I/O constraints (no physical source)
# Create a virtual clock for constraining input and output delays that are synchronous to an external,
# but not explicitly modeled, clock.
create_clock -period 20.000 -name virtual_ext_clk

# Input delay constraints referenced to virtual_ext_clk
set_input_delay -clock virtual_ext_clk -max 5.000 [get_ports DATA_IN]
set_input_delay -clock virtual_ext_clk -min 1.000 [get_ports DATA_IN]

# Output delay constraints referenced to clk_div2
set_output_delay -clock clk_div2 -max 3.000 [get_ports DATA_OUT]
set_output_delay -clock clk_div2 -min 0.500 [get_ports DATA_OUT]
