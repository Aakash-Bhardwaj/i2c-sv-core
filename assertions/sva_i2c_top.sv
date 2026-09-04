module sva_i2c_top #(
    parameter int         DATA_WIDTH     = 8,
    parameter int         CLOCK_FREQ_HZ  = 50_000_000,
    parameter int         SCL_FREQ_HZ    = 100_000,
    parameter logic [6:0] SLAVE_ADDR     = 7'h42,
    parameter int         STRETCH_CYCLES = 0
)(
    input  logic                  clk,
    input  logic                  rst_n,

    // Master interface
    input  logic                  start,
    input  logic [6:0]            slave_addr,
    input  logic                  rw,
    input  logic [DATA_WIDTH-1:0] master_tx_data,
    input  logic [DATA_WIDTH-1:0] master_rx_data,
    input  logic                  master_busy,
    input  logic                  master_done,
    input  logic                  master_error,

    // Slave interface
    input  logic [DATA_WIDTH-1:0] slave_tx_data,
    input  logic [DATA_WIDTH-1:0] slave_rx_data,
    input  logic                  slave_busy,
    input  logic                  slave_done,
    input  logic                  slave_error,

    // I2C bus
    input  wire                   sda,
    input  wire                   scl
);

    // Mutually Exclusive States: Master and Slave cannot be busy and done simultaneously
    always @(posedge clk) begin
        if (rst_n) begin
            assert (!(master_busy && master_done))
                else $error("[SVA] I2C Master is both BUSY and DONE simultaneously");
            assert (!(slave_busy && slave_done))
                else $error("[SVA] I2C Slave is both BUSY and DONE simultaneously");
        end
    end

    // Unknown (X/Z) Value Checks for Outputs
    always @(posedge clk) begin
        if (rst_n) begin
            // Master checks
            assert (!$isunknown(master_rx_data)) else $error("[SVA] master_rx_data contains X");
            assert (!$isunknown(master_busy))    else $error("[SVA] master_busy contains X");
            assert (!$isunknown(master_done))    else $error("[SVA] master_done contains X");
            assert (!$isunknown(master_error))   else $error("[SVA] master_error contains X");

            // Slave checks
            assert (!$isunknown(slave_rx_data))  else $error("[SVA] slave_rx_data contains X");
            assert (!$isunknown(slave_busy))     else $error("[SVA] slave_busy contains X");
            assert (!$isunknown(slave_done))     else $error("[SVA] slave_done contains X");
            assert (!$isunknown(slave_error))    else $error("[SVA] slave_error contains X");
        end
    end

    // Strict 1-Cycle Pulse Checks for 'done' signals
    logic master_done_prev;
    logic slave_done_prev;

    always @(posedge clk) begin
        if (!rst_n) begin
            master_done_prev <= 1'b0;
            slave_done_prev  <= 1'b0;
        end else begin
            master_done_prev <= master_done;
            slave_done_prev  <= slave_done;

            // Master pulse check
            if (master_done_prev) begin
                assert (!master_done)
                    else $error("[SVA] master_done signal remained asserted for more than 1 clock cycle");
            end

            // Slave pulse check
            if (slave_done_prev) begin
                assert (!slave_done)
                    else $error("[SVA] slave_done signal remained asserted for more than 1 clock cycle");
            end
        end
    end

endmodule
