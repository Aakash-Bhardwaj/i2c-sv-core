# I2C Top Timing Constraints

# 50 MHz clock
create_clock -name clk -period 20.0 [get_ports clk]

# Input delays
set_input_delay 0.0 -clock clk \
    [get_ports {rst_n start slave_addr* rw master_tx_data* slave_tx_data*}]

# Output delays
set_output_delay 0.0 -clock clk \
    [get_ports {master_rx_data* master_busy master_done master_error \
                slave_rx_data* slave_busy slave_done slave_error}]

# SDA/SCL are asynchronous bidirectional open-drain bus pins.
# They are not part of the synchronous core timing analysis.
set_disable_timing [get_ports {sda scl}]