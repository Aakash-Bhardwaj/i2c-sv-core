module i2c_slave #(
    parameter int         DATA_WIDTH     = 8,
    parameter logic [6:0] SLAVE_ADDR     = 7'h42,
    parameter int         STRETCH_CYCLES = 0
)(
    input  logic                  clk,
    input  logic                  rst_n,
    // Data interface
    input  logic [DATA_WIDTH-1:0] tx_data,
    output logic [DATA_WIDTH-1:0] rx_data,
    // Status outputs
    output logic                  busy,
    output logic                  done,
    output logic                  error,
    // I²C bus
    inout  wire                   sda,
    inout  wire                   scl
);

    // Local parameters
    localparam int BIT_CNT_WIDTH     = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);
    localparam int STRETCH_CNT_WIDTH = (STRETCH_CYCLES <= 1) ? 1 : $clog2(STRETCH_CYCLES + 1);

    // State encoding
    typedef enum logic [2:0] {
        IDLE,
        ADDRESS,
        ADDRESS_ACK,
        DATA_TRANSFER,
        DATA_TRANSFER_ACK,
        STOP
    } state_t;
    state_t state, next_state;

    // Configuration registers
    logic rw_reg, next_rw;

    // Datapath registers
    logic [DATA_WIDTH-1:0] tx_shift_reg, next_tx_shift;
    logic [DATA_WIDTH-1:0] tx_data_reg, next_tx_data;
    logic [DATA_WIDTH-1:0] rx_shift_reg, next_rx_shift;
    logic [DATA_WIDTH-1:0] rx_data_reg, next_rx_data;
    logic [7:0]            address_shift_reg, next_address_shift;

    // Control registers
    logic [BIT_CNT_WIDTH:0]       bit_count, next_bit_count;
    logic [STRETCH_CNT_WIDTH-1:0] stretch_count, next_stretch_count;

    // Bus interface registers
    logic sda_sync1, sda_in;
    logic scl_sync1, scl_in;
    logic stretch_request, next_stretch_request;
    logic sda_drive_low, next_sda_drive_low;
    logic scl_drive_low, next_scl_drive_low;

    // Output registers
    logic busy_reg, next_busy;
    logic done_reg, next_done;
    logic error_reg, next_error;

    // Internal signals
    logic start_detected;
    logic stop_detected;
    logic scl_rising;
    logic scl_falling;
    logic transfer_finish;

    // Internal signal assignment
    assign scl_rising      = !scl_in && scl_sync1;
    assign scl_falling     = scl_in && !scl_sync1;
    assign start_detected  = sda_in && !sda_sync1 && scl_in;
    assign stop_detected   = !sda_in && sda_sync1 && scl_in;
    assign transfer_finish = (bit_count == DATA_WIDTH - 1);

    // Synchronization
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            sda_sync1 <= 1'b1;
            sda_in    <= 1'b1;
            scl_sync1 <= 1'b1;
            scl_in    <= 1'b1;
        end
        else begin
            sda_sync1 <= sda;
            sda_in    <= sda_sync1;
            scl_sync1 <= scl;
            scl_in    <= scl_sync1;
        end
    end

    // Clock stretching controller
    always_comb begin
        next_stretch_count = stretch_count;
        next_scl_drive_low = 1'b0;
        if (STRETCH_CYCLES == 0) begin
            next_stretch_count = '0;
        end
        else if (stretch_request) begin
            // Start the requested stretch period.
            next_scl_drive_low = 1'b1;
            next_stretch_count = STRETCH_CYCLES;
        end
        // Hold for required cycles
        else if (stretch_count != 0) begin
            next_scl_drive_low = 1'b1;
            if (stretch_count == 1)
                next_stretch_count = '0;
            else
                next_stretch_count = stretch_count - 1'b1;
        end
    end

    // State transition logic
    always_comb begin
        next_state           = state;
        next_rw              = rw_reg;
        next_address_shift   = address_shift_reg;
        next_tx_shift        = tx_shift_reg;
        next_tx_data         = tx_data_reg;
        next_rx_shift        = rx_shift_reg;
        next_rx_data         = rx_data_reg;
        next_bit_count       = bit_count;
        next_stretch_request = 1'b0;
        next_sda_drive_low   = sda_drive_low;
        next_busy            = busy_reg;
        next_done            = 1'b0;
        next_error           = error_reg;
        case (state)
            IDLE: begin
                next_busy = 1'b0;
                next_done = 1'b0;
                if (start_detected) begin
                    next_busy          = 1'b1;
                    next_error         = 1'b0;
                    next_tx_data       = tx_data;
                    next_tx_shift      = tx_data;
                    next_rx_shift      = '0;
                    next_bit_count     = '0;
                    next_address_shift = '0;
                    next_state         = ADDRESS;
                end
            end

            ADDRESS: begin
                if (stop_detected) begin
                    next_state = STOP;
                    next_busy  = 1'b0;
                end
                else if (start_detected) begin
                    next_bit_count     = '0;
                    next_address_shift = '0;
                    next_tx_data       = tx_data;
                    next_tx_shift      = tx_data;
                end
                else if (scl_rising) begin
                    next_address_shift = {address_shift_reg[6:0], sda_in};
                    if (bit_count == 7) begin
                        next_rw        = sda_in;
                        next_bit_count = '0;
                        next_state     = ADDRESS_ACK;
                    end
                    else begin
                        next_bit_count = bit_count + 1'b1;
                    end
                end
            end

            ADDRESS_ACK: begin
                if (stop_detected) begin
                    next_sda_drive_low = 1'b0;
                    next_busy          = 1'b0;
                    next_state         = STOP;
                end
                else if (start_detected) begin
                    next_sda_drive_low = 1'b0;
                    next_bit_count     = '0;
                    next_address_shift = '0;
                    next_tx_data       = tx_data;
                    next_tx_shift      = tx_data;
                    next_state         = ADDRESS;
                end
                else begin
                    if (scl_falling) begin
                        if (address_shift_reg[7:1] == SLAVE_ADDR) begin
                            next_sda_drive_low = 1'b1;
                            // Check for clock stretching
                            next_stretch_request = (STRETCH_CYCLES > 0);
                        end
                    end
                    if (scl_rising) begin
                        if (address_shift_reg[7:1] == SLAVE_ADDR) begin
                            next_bit_count = '0;
                            next_state     = DATA_TRANSFER;
                        end
                        else begin
                            next_state = IDLE;
                            next_busy  = 1'b0;
                        end
                    end
                end
            end

            DATA_TRANSFER: begin
                if (stop_detected) begin
                    next_sda_drive_low = 1'b0;
                    next_busy          = 1'b0;
                    next_state         = STOP;
                end
                else if (start_detected) begin
                    next_sda_drive_low = 1'b0;
                    next_bit_count     = '0;
                    next_address_shift = '0;
                    next_tx_data       = tx_data;
                    next_tx_shift      = tx_data;
                    next_state         = ADDRESS;
                end
                else begin
                    // Master write (Slave read)
                    if (!rw_reg) begin
                        if (scl_falling) begin
                            next_sda_drive_low = 1'b0;
                        end
                        if (scl_rising) begin
                            next_rx_shift = rx_shift_reg << 1;
                            next_rx_shift[0] = sda_in;
                            if (transfer_finish) begin
                                next_bit_count = '0;
                                next_state     = DATA_TRANSFER_ACK;
                            end
                            else begin
                                next_bit_count = bit_count + 1'b1;
                            end
                        end
                    end

                    // Master read (Slave write)
                    else begin
                        if (scl_falling) begin
                            next_sda_drive_low = ~tx_shift_reg[DATA_WIDTH-1];
                            next_tx_shift      = tx_shift_reg << 1;
                        end
                        if (scl_rising) begin
                            if (transfer_finish) begin
                                next_bit_count = '0;
                                next_state     = DATA_TRANSFER_ACK;
                            end
                            else begin
                                next_bit_count = bit_count + 1'b1;
                            end
                        end
                    end
                end
            end

            DATA_TRANSFER_ACK: begin
                if (stop_detected) begin
                    next_sda_drive_low = 1'b0;
                    next_busy          = 1'b0;
                    next_state         = STOP;
                end
                else if (start_detected) begin
                    next_sda_drive_low = 1'b0;
                    next_bit_count     = '0;
                    next_address_shift = '0;
                    next_tx_data       = tx_data;
                    next_tx_shift      = tx_data;
                    next_state         = ADDRESS;
                end
                else begin
                    // Master write (Slave acknowledges read)
                    if (!rw_reg) begin
                        if (scl_falling) begin
                            next_sda_drive_low = 1'b1;
                            // Check for clock stretching
                            next_stretch_request = (STRETCH_CYCLES > 0);
                        end
                        if (scl_rising) begin
                            next_rx_data       = rx_shift_reg;
                            next_bit_count     = '0;
                            next_state         = DATA_TRANSFER;
                        end
                    end

                    // Master read (Slave releases SDA and samples masters NACK/ACK)
                    else begin
                        if (scl_falling) begin
                            next_sda_drive_low = 1'b0;
                            // Check for clock stretching (no NACK)
                            if (bit_count == 0) next_stretch_request = (STRETCH_CYCLES > 0);
                        end
                        if (scl_rising) begin
                            // Process ACK/NACK if no NACK yet
                            if (bit_count == 0) begin
                                if (sda_in) begin
                                    // Master sent NACK; wait for STOP or repeated START.
                                    next_bit_count = 1'b1;
                                end
                                else begin
                                    // Master sent ACK; prepare the next byte.
                                    next_tx_shift  = tx_data_reg;
                                    next_bit_count = '0;
                                    next_state     = DATA_TRANSFER;
                                end
                            end
                        end
                    end
                end
            end

            STOP: begin
                next_sda_drive_low = 1'b0;
                next_busy          = 1'b0;
                next_done          = 1'b1;
                next_state         = IDLE;
            end

            default: begin
                next_state = IDLE;
            end
        endcase
    end

    // Registers
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state             <= IDLE;
            rw_reg            <= 1'b0;
            tx_shift_reg      <= '0;
            tx_data_reg       <= '0;
            rx_shift_reg      <= '0;
            rx_data_reg       <= '0;
            address_shift_reg <= '0;
            bit_count         <= '0;
            stretch_count     <= '0;
            stretch_request   <= 1'b0;
            sda_drive_low     <= 1'b0;
            scl_drive_low     <= 1'b0;
            busy_reg          <= 1'b0;
            done_reg          <= 1'b0;
            error_reg         <= 1'b0;
        end
        else begin
            state             <= next_state;
            rw_reg            <= next_rw;
            tx_shift_reg      <= next_tx_shift;
            tx_data_reg       <= next_tx_data;
            rx_shift_reg      <= next_rx_shift;
            rx_data_reg       <= next_rx_data;
            address_shift_reg <= next_address_shift;
            bit_count         <= next_bit_count;
            stretch_count     <= next_stretch_count;
            stretch_request   <= next_stretch_request;
            sda_drive_low     <= next_sda_drive_low;
            scl_drive_low     <= next_scl_drive_low;
            busy_reg          <= next_busy;
            done_reg          <= next_done;
            error_reg         <= next_error;
        end
    end

    // Output logic
    assign rx_data = rx_data_reg;
    assign busy    = busy_reg;
    assign done    = done_reg;
    assign error   = error_reg;

    // Bus interface
    assign sda = sda_drive_low ? 1'b0 : 1'bz;
    assign scl = scl_drive_low ? 1'b0 : 1'bz;

    // synthesis translate_off

    // Parameter validation
    initial begin
        bit error_check;
        error_check = 0;
        if (DATA_WIDTH <= 0) begin
            $error("DATA_WIDTH must be greater than 0.");
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
