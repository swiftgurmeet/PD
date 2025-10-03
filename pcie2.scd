####################################################################################################
#
# PCIe IP Top-Level SDC Constraints for Primetime STA
#
# This file is for signoff STA and assumes a pre-existing hierarchical design.
# It is meant to be sourced at the top level of the SoC and contains constraints
# for the PCIe IP, including its clocking, asynchronous bridges, and reset logic.
#
####################################################################################################

# ==================================================================================================
#                                          VARIABLES
# ==================================================================================================

# Core clock frequencies
set core_clk_freq_mhz       300
set core_clk_period_ns      [expr {1000.0 / $core_clk_freq_mhz}]

# PCIe reference clock frequency (100MHz nominal)
set pcie_ref_clk_freq_mhz   100
set pcie_ref_clk_period_ns  [expr {1000.0 / $pcie_ref_clk_freq_mhz}]

# PCIe PIPE Interface clock frequency (e.g., for PCIe Gen4 x16)
set pcie_pipe_clk_freq_mhz  250
set pcie_pipe_clk_period_ns [expr {1000.0 / $pcie_pipe_clk_freq_mhz}]

# IP instance name
set pcie_inst               [get_cells -hierarchical {U_PCIE_IP}]

# Clock port names
set core_clk_port           [get_ports {core_clk_in}]
set pcie_ref_clk_port       [get_ports {pcie_ref_clk_in_p}]

# ==================================================================================================
#                                         CLOCK DEFINITIONS
# ==================================================================================================

# Define the SoC core clock from a top-level port
create_clock -name core_clk -period $core_clk_period_ns [get_ports $core_clk_port]

# Define the PCIe reference clock from a top-level port
# The standard requires specific ppm stability, which is typically handled by the IP vendor's
# library and models. The SDC only defines the base frequency.
create_clock -name pcie_ref_clk -period $pcie_ref_clk_period_ns [get_ports $pcie_ref_clk_port]

# Define the high-speed PIPE interface clock
# This clock is typically generated inside the IP by a PLL.
# The following is a generated clock constraint derived from the reference clock.
create_generated_clock -name pcie_pipe_clk -source [get_ports $pcie_ref_clk_port] \
  -divide_by [expr {$pcie_ref_clk_freq_mhz / $pcie_pipe_clk_freq_mhz}] \
  [get_pins -of_objects $pcie_inst {*pipe_clk_pin*}]

# ==================================================================================================
#                                       CLOCK RELATIONSHIPS
# ==================================================================================================

# The PCIe reference clock, core clock, and generated pipe clock are asynchronous.
# Standard cross-clock domain (CDC) paths must be constrained as false paths to prevent
# timing analysis errors. Synchronization logic (like double-flops) is required in RTL.
set_clock_groups -asynchronous -group {core_clk} -group {pcie_ref_clk} -group {pcie_pipe_clk}

# The reset signal is typically asynchronous and must be handled correctly.
set_false_path -from [get_ports {pcie_reset_n}] -to [get_pins -of_objects $pcie_inst -filter {name =~ "*rst_reg*"}]

# ==================================================================================================
#                                       CDC EXCEPTIONS
# ==================================================================================================

# Create a more granular way to handle CDC paths instead of setting all paths false.
# This approach uses specific paths through the synchronization elements.
# Assuming the CDC is handled by a standard two-flip-flop synchronizer `cdc_sync`.
# We target the specific data path entering the IP and crossing the clock domain.

# Example: Paths from core_clk domain to pcie_pipe_clk domain
set_max_delay -from [get_cells {*core_data_reg*}] -to [get_cells {*pcie_sync_flops_inst*}] 10
set_false_path -through [get_cells {*pcie_sync_flops_inst*}/Q]

# Example: Paths from pcie_pipe_clk domain to core_clk domain
set_max_delay -from [get_cells {*pcie_data_reg*}] -to [get_cells {*core_sync_flops_inst*}] 10
set_false_path -through [get_cells {*core_sync_flops_inst*}/Q]

# ==================================================================================================
#                                       PHY-specific Constraints
# ==================================================================================================

# The PCIe PHY interface (PIPE) often has complex timing requirements, including source-synchronous
# and system-synchronous timing depending on the IP generation.

# -----------------
# Source-Synchronous Interface (common for older PHYs)
# -----------------
# The PHY might generate a source-synchronous clock. This needs to be defined.
# Assumes a source-synchronous clock `pipe_tx_clk` is forwarded with data.
# set_input_delay -clock [get_clocks pcie_pipe_clk] -max 1.5 [get_ports {pcie_tx_data*}]
# set_input_delay -clock [get_clocks pcie_pipe_clk] -min 0.5 [get_ports {pcie_tx_data*}]
# set_output_delay -clock [get_clocks pcie_pipe_clk] -max 1.0 [get_ports {pcie_rx_data*}]
# set_output_delay -clock [get_clocks pcie_pipe_clk] -min 0.2 [get_ports {pcie_rx_data*}]

# -----------------
# Advanced PHY Interface Constraints (for modern PHYs)
# -----------------
# Modern PHYs often have internal timing and may require special exceptions for "gray-box" STA.
# The vendor's SDC often provides specific commands for this.
# Example: Relax timing on certain buses that are internally managed by the PHY.
set_false_path -to [get_pins $pcie_inst/PIPE_INTERFACE_INST/*rx_valid]
set_false_path -from [get_pins $pcie_inst/PIPE_INTERFACE_INST/*tx_data]

# ==================================================================================================
#                                       ASYNCHRONOUS INTERFACES
# ==================================================================================================

# Isolate the PCIe core from the main SoC logic for specific asynchronous paths.
# This is a good practice for minimizing paths that need manual handling.
set_false_path -from [get_clocks core_clk] -to [get_clocks pcie_ref_clk]
set_false_path -from [get_clocks pcie_ref_clk] -to [get_clocks core_clk]

# Ensure that the reset synchronization is correctly constrained.
# The reset path from the top-level pin to the first register in the PCIe IP must be timed.
# The path after the synchronizer can be ignored.
set_max_delay -from [get_ports {pcie_reset_n}] -to [get_pins $pcie_inst/RESET_SYNC_INST/*rst_reg_in] 5

# ==================================================================================================
#                                       TIMING EXCEPTIONS (Multi-Cycle Paths)
# ==================================================================================================

# PCIe controllers often have slow, multi-cycle data paths, particularly for configuration
# and status registers.

# Example: Assuming a 16-cycle path for configuration register access.
set_multicycle_path 16 -setup -from [get_clocks core_clk] -to [get_pins $pcie_inst/CFG_REG_INST/*]
set_multicycle_path 15 -hold  -from [get_clocks core_clk] -to [get_pins $pcie_inst/CFG_REG_INST/*]

# Example: A multi-cycle path for the AXI interface to the user logic
# This applies to slower register accesses, not the high-speed data path.
set_multicycle_path 4 -setup -from [get_pins $pcie_inst/AXI_INST/*req_reg] -to [get_pins *axil_resp_reg*]
set_multicycle_path 3 -hold  -from [get_pins $pcie_inst/AXI_INST/*req_reg] -to [get_pins *axil_resp_reg*]

# ==================================================================================================
#                                        JITTER AND UNCERTAINTY
# ==================================================================================================

# Apply jitter and uncertainty settings, which are crucial for high-speed interfaces.
# These values should be provided by the PCIe IP vendor.
set_clock_uncertainty -setup 0.05 [get_clocks pcie_ref_clk]
set_clock_uncertainty -hold 0.02 [get_clocks pcie_ref_clk]

# Add additional uncertainty for clock domain crossing paths
set_clock_uncertainty 0.2 -from [get_clocks core_clk] -to [get_clocks pcie_pipe_clk]
set_clock_uncertainty 0.2 -from [get_clocks pcie_pipe_clk] -to [get_clocks core_clk]

# Account for clock jitter on the core clock
set_clock_jitter 0.08 [get_clocks core_clk]

# ==================================================================================================
#                                        MODE AND CORNER SETUP
# ==================================================================================================

# Set operating conditions for signoff analysis.
set_operating_conditions -max fast_corner -max_library fast_libs
set_operating_conditions -min slow_corner -min_library slow_libs

# Handle power management, which is critical for PCIe.
# For STA, this can involve setting false paths for logic that is powered down.
# For example, ignore timing paths related to deep sleep or power down.
# set_case_analysis 0 [get_pins {*pcie_power_down_mode_reg*/Q}]

