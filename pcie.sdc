####################################################################################################
#
# SDC for Top-Level PCIe IP Integration
#
# This file provides a comprehensive SDC template for constraining a PCIe IP block within a
# larger SoC. It assumes a design hierarchy where the PCIe IP is instantiated as `u_pcie_mac_phy`.
#
# Assumptions:
# - Top-level clocks: `sys_clk`, `sys_rst_n`, and `pci_ref_clk`.
# - PCIe IP instance: `u_pcie_mac_phy`.
# - PCIe PHY interface: `pcie_serdes_rx_p`, `pcie_serdes_rx_n`, `pcie_serdes_tx_p`, `pcie_serdes_tx_n`.
# - PCIe MAC interface: `pcie_app_clk`, `pcie_app_rst_n`, `pcie_app_data`, etc.
#
####################################################################################################

# ==================================================================================================
# Clock Definitions
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Primary Clocks
# --------------------------------------------------------------------------------------------------

# Define the main system clock.
create_clock -name sys_clk -period 1.0 [get_ports sys_clk]

# Define the PCIe reference clock (e.g., 100 MHz).
# This clock is asynchronous to the main system clock.
create_clock -name pci_ref_clk -period 10.0 [get_ports pci_ref_clk]

# --------------------------------------------------------------------------------------------------
# Generated Clocks for the PCIe IP
# --------------------------------------------------------------------------------------------------

# Assuming the IP generates multiple clocks from its internal PLLs.
# These generated clocks must be defined to propagate constraints correctly.
# The exact clock names will depend on the IP's internal implementation.

# Example: Define the application interface clock (e.g., 250 MHz for PCIe Gen3).
# The PCIe IP instance is `u_pcie_mac_phy`. The clock is sourced from an internal PLL output.
create_generated_clock -name pcie_app_clk \
  -source [get_pins u_pcie_mac_phy/inst_pll_ref_clk_out] \
  -divide_by 4 \
  -add \
  [get_pins u_pcie_mac_phy/inst_pll_clk_out]

# Example: Define the high-speed serializer clock (rate clock).
# The source should be the actual internal PLL output pin.
create_generated_clock -name pcie_serdes_rate_clk \
  -source [get_pins u_pcie_mac_phy/inst_pll_ref_clk_out] \
  -multiply_by 40 \
  -add \
  [get_pins u_pcie_mac_phy/inst_serdes_rate_clk_out]

# ==================================================================================================
# Reset Constraints
# ==================================================================================================

# The PCIe reset is typically asynchronous and should be properly constrained.
# The reset is assumed to be active low (`pci_reset_n`).

# Treat `pci_reset_n` as a pure asynchronous reset.
set_false_path -from [get_ports pci_reset_n]

# The internal reset path may need a release check.
# This depends on whether the reset is synchronized inside the IP.
# If the IP has internal synchronizers, you can define a `set_max_delay` constraint for the reset path.
# Example for a synchronized reset (if applicable):
# set_max_delay 2.0 -from [get_ports pci_reset_n] -to [get_pins {u_pcie_mac_phy/*rst_sync_ff*}]

# ==================================================================================================
# Clock Domain Crossing (CDC) Constraints
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Asynchronous Clock Groups
# --------------------------------------------------------------------------------------------------

# The `pci_ref_clk` and the system clock domain are asynchronous.
set_clock_groups -asynchronous \
  -group {sys_clk} \
  -group {pci_ref_clk pcie_app_clk pcie_serdes_rate_clk}

# The above command tells the STA tool to ignore timing paths between these clock domains.
# It is critical that all CDC paths are handled by proper synchronization logic (e.g., 2-FF synchronizers)
# and constrained with false paths or max delays on the synchronizer stages.

# --------------------------------------------------------------------------------------------------
# CDC Exceptions
# --------------------------------------------------------------------------------------------------

# Example of a CDC path from the system domain to the PCIe domain.
# The destination of the path is assumed to be a 2-FF synchronizer.
set_false_path -from [get_clocks sys_clk] -to [get_clocks pcie_app_clk] \
  -through [get_pins {u_pcie_cdc/sync_reg1_reg/D}]
# The `-through` option is crucial for accuracy.

# Example of a CDC path from the PCIe domain to the system domain.
set_false_path -from [get_clocks pcie_app_clk] -to [get_clocks sys_clk] \
  -through [get_pins {u_pcie_cdc/sync_reg1_reg/D}]

# ==================================================================================================
# I/O Constraints for PCIe High-Speed Serial Interface
# ==================================================================================================

# The SERDES interface is typically handled internally by the IP and requires specific
# timing parameters for board-level design. These constraints model the interface.

# High-speed serial links (SERDES) are typically not timed by SDC.
# Use false path to exclude these high-speed pins from STA.
set_false_path -from [get_ports {pcie_serdes_rx_p[*] pcie_serdes_rx_n[*]}]
set_false_path -to [get_ports {pcie_serdes_tx_p[*] pcie_serdes_tx_n[*]}]

# If there are any digital control signals crossing this boundary, they should be constrained separately.

# ==================================================================================================
# Configuration and Mode-Dependent Constraints
# ==================================================================================================

# Many IP blocks have different operational modes controlled by static configuration pins.
# Using `set_case_analysis` is essential for handling these modes in STA.

# Example: Model a link training sequence where certain paths are not active during normal operation.
# `pcie_cfg_link_train_mode` is a top-level input pin.
set_case_analysis 0 [get_ports pcie_cfg_link_train_mode]

# Example: Configure the IP for a specific PCIe generation (e.g., Gen3).
# `u_pcie_mac_phy/cfg_pcie_gen` is an internal signal.
set_case_analysis 3 [get_pins u_pcie_mac_phy/cfg_pcie_gen]

# Example: Constraining the IP for a specific power state.
# `pcie_power_state` is a top-level input pin.
set_case_analysis 0 [get_ports pcie_power_state]

# ==================================================================================================
# Multi-cycle Path Exceptions
# ==================================================================================================

# Some paths within the IP or crossing between the IP and the SoC may require multiple clock cycles.
# These need to be explicitly defined to relax timing requirements.

# Example: A status register update from the PCIe IP to the system domain.
# Assuming the status is synchronized across CDC and can take up to 3 cycles.
set_multicycle_path 3 -setup \
  -from [get_pins u_pcie_mac_phy/inst_status_reg_reg/C] \
  -to [get_pins u_pcie_top/u_soc_logic/status_sync_ff1_reg/D]
set_multicycle_path 2 -hold \
  -from [get_pins u_pcie_mac_phy/inst_status_reg_reg/C] \
  -to [get_pins u_pcie_top/u_soc_logic/status_sync_ff1_reg/D]

# ==================================================================================================
# False Path Exceptions
# ==================================================================================================

# Exclude paths that are logically false, such as control paths that are static during a specific mode.
# Example: Configuration registers that are only loaded once at startup.
set_false_path -from [get_pins {u_pcie_mac_phy/inst_config_reg[*]/C}]

# Exclude specific internal CDC synchronizers, as they are intentionally multi-cycle.
# This prevents timing errors from being reported on the first stage of the synchronizer.
set_false_path -from [get_pins {u_pcie_mac_phy/inst_cdc_path/sync_reg1_reg/C}] \
  -to [get_pins {u_pcie_mac_phy/inst_cdc_path/sync_reg2_reg/D}]

# ==================================================================================================
# I/O Delays for the Application Layer Interface
# ==================================================================================================

# Define input and output delays for the synthesized application interface of the PCIe IP.
# The delays represent the external chip-level timing requirements.

# Example for input data `pcie_app_data_in` on `pcie_app_clk`.
set_input_delay -clock pcie_app_clk 2.0 [get_ports pcie_app_data_in[*]]
set_input_delay -clock pcie_app_clk 1.5 [get_ports pcie_app_data_in[*]] -min

# Example for output data `pcie_app_data_out` on `pcie_app_clk`.
set_output_delay -clock pcie_app_clk 1.5 [get_ports pcie_app_data_out[*]]
set_output_delay -clock pcie_app_clk 1.0 [get_ports pcie_app_data_out[*]] -min

# ==================================================================================================
# Advanced Constraints and Considerations
# ==================================================================================================

# --------------------------------------------------------------------------------------------------
# Spread Spectrum Clocking (SSC)
# --------------------------------------------------------------------------------------------------

# If the `pci_ref_clk` uses SSC, you must constrain it carefully.
# The frequency modulation is too slow to impact STA, but it does mean the clock is not truly fixed.
# The `create_clock` definition remains the same, but the asynchronous clock grouping is critical.

# --------------------------------------------------------------------------------------------------
# JTAG and Test Modes
# --------------------------------------------------------------------------------------------------

# Exclude JTAG-related paths from normal timing analysis.
set_false_path -from [get_ports tdi]
set_false_path -to [get_ports tdo]

# For test modes, use `set_case_analysis` or separate SDC files.
# Example: `set_case_analysis 1 [get_ports pcie_test_mode_en]`

# --------------------------------------------------------------------------------------------------
# Low-Power States
# --------------------------------------------------------------------------------------------------

# Exclude clocks in low-power states to prevent unnecessary timing analysis.
# Example: When `pcie_link_state` is 'OFF', disable the clock.
# set_case_analysis 0 [get_pins u_pcie_mac_phy/link_pwr_off_reg/Q]
# set_disable_timing -from [get_ports pci_ref_clk] -to [get_pins u_pcie_mac_phy/inst_pll_ref_clk_in]

# ==================================================================================================
# End of SDC
# ==================================================================================================

