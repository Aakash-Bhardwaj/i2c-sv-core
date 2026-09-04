module i2c_top #(
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
    output logic [DATA_WIDTH-1:0] master_rx_data,
    output logic                  master_busy,
    output logic                  master_done,
    output logic                  master_error,

    // Slave interface
    input  logic [DATA_WIDTH-1:0] slave_tx_data,
    output logic [DATA_WIDTH-1:0] slave_rx_data,
    output logic                  slave_busy,
    output logic                  slave_done,
    output logic                  slave_error,

    // I2C bus
    inout wire                    sda,
    inout wire                    scl
);
    // Master instance
    i2c_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .SCL_FREQ_HZ(SCL_FREQ_HZ)
    ) master (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .tx_data(master_tx_data),
        .rx_data(master_rx_data),
        .busy(master_busy),
        .done(master_done),
        .error(master_error),
        .sda(sda),
        .scl(scl)
    );

    // Slave instance
    i2c_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_ADDR(SLAVE_ADDR),
        .STRETCH_CYCLES(STRETCH_CYCLES)
    ) slave (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(slave_tx_data),
        .rx_data(slave_rx_data),
        .busy(slave_busy),
        .done(slave_done),
        .error(slave_error),
        .sda(sda),
        .scl(scl)
    );

    // synthesis translate_off

    // Parameter validation
    initial begin
        bit error_check;
        error_check = 0;
        if (DATA_WIDTH <= 0) begin
            $error("DATA_WIDTH must be greater than 0.");
            error_check = 1;
        end
        if (CLOCK_FREQ_HZ <= 0) begin
            $error("CLOCK_FREQ_HZ must be greater than 0.");
            error_check = 1;
        end
        if (SCL_FREQ_HZ <= 0) begin
            $error("SCL_FREQ_HZ must be greater than 0.");
            error_check = 1;
        end
        if (CLOCK_FREQ_HZ <= SCL_FREQ_HZ) begin
            $error("CLOCK_FREQ_HZ must be greater than SCL_FREQ_HZ.");
            error_check = 1;
        end
        if (STRETCH_CYCLES < 0) begin
            $error("STRETCH_CYCLES must be greater than or equal to 0.");
            error_check = 1;
        end
        if (error_check) begin
            $fatal(0);
        end
    end

    // synthesis translate_on

endmodule
