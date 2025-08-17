# Define the primary clock input
create_clock -name sys_clk -period 10.000 -waveform {0.000 5.000} [get_ports CLK_IN_P]

# Create a virtual clock for an external device's clock
create_clock -name ext_clk_virt -period 8.000

# Define a divided clock generated from the primary clock
# This represents a clock divider circuit (e.g., using a counter or flip-flops)
create_generated_clock -name div_clk -source [get_ports CLK_IN_P] -divide_by 2 [get_pins clock_divider_inst/clk_div_out]

# Define a multiplied clock generated from the primary clock
# This could be from a PLL or a custom clock multiplier circuit
create_generated_clock -name mul_clk -source [get_ports CLK_IN_P] -multiply_by 4 [get_pins pll_inst/clk_out_multiplied]

# Define a generated clock from a different source (e.g., an internal oscillator)
# This clock might not be directly related to the primary input clock
create_generated_clock -name osc_clk -source [get_pins internal_oscillator/clk_out] -period 25.000 -add [get_pins some_reg/CLK]

# Create a generated clock with a specific duty cycle
create_generated_clock -name duty_cycle_clk -source [get_ports CLK_IN_P] -divide_by 4 -duty_cycle 25 [get_pins custom_duty_cycle_gen/clk_out]

# Define a clock that is phase-shifted relative to the primary clock
# This could represent a forwarded clock in a source-synchronous interface
create_generated_clock -name fwd_clk -source [get_ports CLK_IN_P] -edges {2 3 8} [get_ports CLK_OUT_FWD]

# Define a clock at the output of a clock multiplexer
# In this case, two master clocks drive the MUX, and the generated clocks
# represent the clock at the MUX output based on which master is selected
create_generated_clock -source [get_pins clk_mux_inst/OUT] -master_clock sys_clk -name mux_clk_sys [get_pins some_logic/CLK]
create_generated_clock -source [get_pins clk_mux_inst/OUT] -master_clock ext_clk_virt -name mux_clk_ext [get_pins some_logic/CLK] -add

# Handle a forwarded clock through an ODDR (Output Double Data Rate)
# commonly used in source-synchronous interfaces
create_generated_clock -name oddr_fwd_clk -multiply_by 1 -source [get_pins oddr_inst/C] [get_ports CLK_FWD_OUT]

# Constrain input delays relative to a virtual clock
set_input_delay -clock ext_clk_virt -max 1.5 [get_ports DATA_IN]
set_input_delay -clock ext_clk_virt -min 0.5 [get_ports DATA_IN]

# Constrain output delays relative to a real clock
set_output_delay -clock mul_clk -max 1.0 [get_ports DATA_OUT]
set_output_delay -clock mul_clk -min -0.5 [get_ports DATA_OUT]

# Set false paths for asynchronous inputs that are synchronized internally
# The ASYNC_REG property on the synchronizing registers is often also required for proper CDC handling
set_false_path -from [get_ports ASYNC_IN] -to [get_clocks {sys_clk div_clk}]

# Set max delay for asynchronous paths that don't need full clock-to-clock analysis
set_max_delay -from [get_ports ASYNC_DATA] -to [get_pins sync_reg_inst/D] 3 -datapath_only

