module sva_i2c_master #(
    parameter int DATA_WIDTH = 8,
    parameter int CLOCK_FREQ_HZ = 50_000_000,
    parameter int SCL_FREQ_HZ   = 100_000
)(
    input  logic                  clk,
    input  logic                  rst_n,
    input  logic                  start,
    input  logic [6:0]            slave_addr,
    input  logic                  rw,
    input  logic [DATA_WIDTH-1:0] tx_data,
    input  logic [DATA_WIDTH-1:0] rx_data,
    input  logic                  busy,
    input  logic                  done,
    input  logic                  error,
    input  wire                   sda,
    input  wire                   scl
);

// The I2C master cannot be both busy and done at the exact same time
always @(posedge clk) begin
    if (rst_n) begin
        assert (!(busy && done))
            else $error("I2C Master is both BUSY and DONE simultaneously");
    end
end

// Outputs and bidirectional bus lines should never contain unknowns (X or Z values) during active operation
always @(posedge clk) begin
    if (rst_n) begin
        assert (!$isunknown(rx_data))
            else $error("rx_data contains X");

        assert (!$isunknown(busy))
            else $error("busy contains X");

        assert (!$isunknown(done))
            else $error("done contains X");

        assert (!$isunknown(error))
            else $error("error contains X");
    end
end

// Done signal should be a strict one-cycle pulse
logic done_prev;

always @(posedge clk) begin
    if (!rst_n) begin
        done_prev <= 1'b0;
    end else begin
        done_prev <= done;
        if (done_prev) begin
            assert (!done)
                else $error("DONE signal remained asserted for more than 1 clock cycle");
        end
    end
end

endmodule
