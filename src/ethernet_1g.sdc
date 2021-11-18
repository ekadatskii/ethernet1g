


#------------------------------------------------------------------------------------------#
#---------------------------------------RECEIVE SIDE---------------------------------------#
#------------------------------------------------------------------------------------------#
# Create a 125MHz clock
# virtual_source: an ideal clock in the sourcing device
# RX_CLK: input clock port of the interface; 90 deg phase shifted
create_clock -name virtual_source -period 8
create_clock -name rgmii_rx_clk -period 8 -waveform { 2 6 } [get_ports {rgmii_rx_clk}]
# Set input delay based on the requirements mentioned previously
# RX_CLK is 90 deg phase shifted
# Input delay is relative to the rising and falling edges of the clock
set_input_delay -max 0.8 -clock [get_clocks virtual_source] -add_delay [get_ports rgmii_rxd*]
set_input_delay -min -0.8 -clock [get_clocks virtual_source] -add_delay [get_ports rgmii_rxd*]
set_input_delay -max 0.8 -clock_fall -clock [get_clocks virtual_source] -add_delay [get_ports rgmii_rxd*]
set_input_delay -min -0.8 -clock_fall -clock [get_clocks virtual_source] -add_delay [get_ports rgmii_rxd*]

set_input_delay -max 0.8 -clock [get_clocks virtual_source] -add_delay [get_ports {rgmii_rx_ctl}]
set_input_delay -min -0.8 -clock [get_clocks virtual_source] -add_delay [get_ports {rgmii_rx_ctl}]
set_input_delay -max 0.8 -clock_fall -clock [get_clocks virtual_source] -add_delay [get_ports {rgmii_rx_ctl}]
set_input_delay -min -0.8 -clock_fall -clock [get_clocks virtual_source] -add_delay [get_ports {rgmii_rx_ctl}]

# Set false paths to remove irrelevant setup and hold analysis
set_false_path -fall_from [get_clocks virtual_source] -rise_to [get_clocks {rgmii_rx_clk}] -setup
set_false_path -rise_from [get_clocks virtual_source] -fall_to [get_clocks {rgmii_rx_clk}] -setup
set_false_path -fall_from [get_clocks virtual_source] -fall_to [get_clocks {rgmii_rx_clk}] -hold
set_false_path -rise_from [get_clocks virtual_source] -rise_to [get_clocks {rgmii_rx_clk}] -hold