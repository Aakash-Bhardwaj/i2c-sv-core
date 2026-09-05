module i2c_master #(
    parameter int DATA_WIDTH    = 8,
    parameter int CLOCK_FREQ_HZ = 50_000_000,
    parameter int SCL_FREQ_HZ   = 100_000
)(
    input  logic                  clk,
    input  logic                  rst_n,
    // Operation inputs
    input  logic                  start,
    input  logic [6:0]            slave_addr,
    input  logic                  rw,                // Low for read, High for write
    input  logic [DATA_WIDTH-1:0] tx_data,
    // Operation outputs
    output logic [DATA_WIDTH-1:0] rx_data,
    output logic                  busy,
    output logic                  done,
    output logic                  error,
    // Clock and data bus
    inout  wire                   sda,
    inout  wire                   scl
);

    // Local parameters
    localparam int DIVISOR       = CLOCK_FREQ_HZ / (SCL_FREQ_HZ * 4);
    localparam int DIV_WIDTH     = $clog2(DIVISOR);
    localparam int BIT_CNT_WIDTH = (DATA_WIDTH <= 1) ? 1 : $clog2(DATA_WIDTH);

    // State encoding
    // Using one hot encoding to fix timing violations
    typedef enum logic [6:0] {
    IDLE             = 7'b0000001,
    START            = 7'b0000010,
    ADDRESS          = 7'b0000100,
    ADDRESS_ACK      = 7'b0001000,
    DATA_TRANSFER    = 7'b0010000,
    DATA_TRANSFER_ACK= 7'b0100000,
    STOP             = 7'b1000000
    } state_t;
    state_t state, next_state;

    // Phase encoding
    typedef enum logic [1:0] {
        DRIVE,
        RAISE,
        SAMPLE,
        LOWER
    } phase_t;
    phase_t phase, next_phase;

    // Clock generation signals and registers
    logic                     quarter_tick;
    logic                     clock_enable, next_clock_enable;
    logic                     scl_drive_low, next_scl_drive_low;

    // Configuration registers
    logic [6:0]               slave_addr_reg, next_slave_addr;
    logic                     rw_reg, next_rw;

    // Shadow registers for Repeated START buffering
    logic [6:0]               rstart_addr_reg, next_rstart_addr;
    logic                     rstart_rw_reg, next_rstart_rw;
    logic [DATA_WIDTH-1:0]    rstart_tx_data_reg, next_rstart_tx_data;

    // Datapath registers
    logic [DATA_WIDTH-1:0]    tx_shift_reg, next_tx_shift;
    logic [DATA_WIDTH-1:0]    tx_data_reg, next_tx_data;
    logic [DATA_WIDTH-1:0]    rx_shift_reg, next_rx_shift;
    logic [DATA_WIDTH-1:0]    rx_data_reg, next_rx_data;
    logic                     sda_drive_low, next_sda_drive_low;

    // Control registers
    logic [BIT_CNT_WIDTH-1:0] bit_count, next_bit_count;
    logic [DIV_WIDTH-1:0]     divider_reg, next_divider;

    // Internal signals and registers
    logic                     repeated_start_reg, next_repeated_start;
    logic                     last_bit;
    logic                     scl_in, sda_in;

    // Output registers
    logic                     busy_reg, next_busy;
    logic                     done_reg, next_done;
    logic                     error_reg, next_error;

    // Signal Assignment
    assign quarter_tick = (divider_reg == DIVISOR - 1);
    assign last_bit     = (bit_count == DATA_WIDTH - 1);
    assign scl_in       = scl;
    assign sda_in       = sda;

    // SCL generation
    always_comb begin
        next_divider       = divider_reg;
        next_phase         = phase;
        next_scl_drive_low = scl_drive_low;

        if (!clock_enable) begin
            next_divider       = '0;
            next_phase         = DRIVE;
            next_scl_drive_low = 1'b0;
        end
        else begin
            next_divider = divider_reg + 1'b1;

            if (quarter_tick) begin
                // Phase generation (Quarter cycle)
                case (phase)
                    DRIVE: begin
                        next_divider       = '0;
                        next_phase         = RAISE;
                        next_scl_drive_low = 1'b0;
                    end
                    RAISE: begin
                        // Clock stretching check
                        if (!scl_in) begin
                            next_divider       = divider_reg;
                            next_phase         = RAISE;
                            next_scl_drive_low = 1'b0;
                        end
                        else begin
                            next_divider       = '0;
                            next_phase         = SAMPLE;
                            next_scl_drive_low = 1'b0;
                        end
                    end
                    SAMPLE: begin
                        next_divider       = '0;
                        next_phase         = LOWER;
                        if (state == STOP)
                            next_scl_drive_low = 1'b0;
                        else
                            next_scl_drive_low = 1'b1;
                        //next_scl_drive_low = 1'b1;
                    end
                    LOWER: begin
                        next_divider       = '0;
                        next_phase         = DRIVE;
                        if (state == STOP)
                            next_scl_drive_low = 1'b0;
                        else
                            next_scl_drive_low = 1'b1;
                        //next_scl_drive_low = 1'b1;
                    end
                    default: next_phase = DRIVE;
                endcase
            end
        end
    end

    // State transition logic
    always_comb begin
        next_state          = state;
        next_slave_addr     = slave_addr_reg;
        next_rw             = rw_reg;
        next_clock_enable   = clock_enable;
        next_tx_shift       = tx_shift_reg;
        next_tx_data        = tx_data_reg;
        next_rx_shift       = rx_shift_reg;
        next_rx_data        = rx_data_reg;
        next_bit_count      = bit_count;
        next_busy           = busy_reg;
        next_done           = done_reg;
        next_error          = error_reg;
        next_sda_drive_low  = sda_drive_low;
        next_repeated_start = repeated_start_reg;
        next_rstart_addr    = rstart_addr_reg;
        next_rstart_rw      = rstart_rw_reg;
        next_rstart_tx_data = rstart_tx_data_reg;

        // Checking for repeated start
        if (start && busy_reg) begin
            next_repeated_start = 1'b1;
            next_rstart_addr    = slave_addr;
            next_rstart_rw      = rw;
            next_rstart_tx_data = tx_data;
        end
        case(state)
            IDLE: begin
                next_repeated_start = 1'b0;
                next_clock_enable   = 1'b0;
                next_busy           = 1'b0;
                next_done         = 1'b0;
                next_sda_drive_low  = 1'b0;
                if (start) begin
                    next_error        = 1'b0;
                    next_slave_addr   = slave_addr;
                    next_rw           = rw;
                    next_tx_data      = tx_data;
                    next_clock_enable = 1'b1;
                    next_state        = START;
                end
            end

            START: begin
                unique case (phase)
                    DRIVE: begin
                        next_sda_drive_low = 1'b0;
                    end
                    RAISE: ; // IDLE
                    SAMPLE: begin
                        // SDA pulled, when SCL high to generate START condition
                        next_sda_drive_low = 1'b1;
                    end
                    LOWER: begin
                        if (quarter_tick) begin
                            // Updated when SCL low
                            next_tx_shift  = {slave_addr_reg, rw_reg};
                            next_bit_count = '0;
                            next_busy      = 1'b1;
                            next_done      = 1'b0;
                            next_error     = 1'b0;
                            next_state     = ADDRESS;
                        end
                    end
                endcase
            end

            ADDRESS: begin
                // Address transfer synchronized with phases
                unique case (phase)
                    DRIVE: begin
                        // MSB as SDA
                        next_sda_drive_low = ~tx_shift_reg[DATA_WIDTH-1];
                    end
                    RAISE, SAMPLE: ; // IDLE
                    LOWER: begin
                        if (quarter_tick) begin
                            // Shift and advance after the clock pulse
                            if (!last_bit) begin
                                next_tx_shift  = tx_shift_reg << 1;
                                next_bit_count = bit_count + 1'b1;
                            end
                            else begin
                                next_bit_count = '0;
                                next_state     = ADDRESS_ACK;
                            end
                        end
                    end
                endcase
            end

            ADDRESS_ACK: begin
                unique case (phase)
                    DRIVE: begin
                        // Release SDA
                        next_sda_drive_low = 1'b0;
                    end
                    RAISE: ; // IDLE
                    SAMPLE: begin
                        if (quarter_tick) begin
                            // Check for NACK
                            if (sda_in) begin
                                next_error = 1'b1;
                            end
                        end
                    end
                    LOWER: begin
                        if (quarter_tick) begin
                            if (error_reg) begin
                                next_state = STOP;
                            end
                            else begin
                                next_tx_shift  = tx_data_reg;
                                next_bit_count = '0;
                                next_state     = DATA_TRANSFER;
                            end
                        end
                    end
                endcase
            end

            DATA_TRANSFER: begin
                // Data transfer synchronized with phases
                unique case (phase)
                    DRIVE: begin
                        // MSB as SDA if write
                        if (!rw_reg)
                            next_sda_drive_low = ~tx_shift_reg[DATA_WIDTH-1];
                    end
                    RAISE: ; // IDLE
                    SAMPLE: begin
                        if (quarter_tick) begin
                            // SDA sampled and stored if read
                            if (rw_reg)
                                next_rx_shift = {rx_shift_reg[DATA_WIDTH-2:0], sda_in};
                        end
                    end
                    LOWER: begin
                        if (quarter_tick) begin
                            // Shift (for write) and advance after the clock pulse
                            if (!last_bit) begin
                                next_bit_count = bit_count + 1'b1;
                                if (!rw_reg)
                                    next_tx_shift = tx_shift_reg << 1;
                            end
                            else begin
                                next_state = DATA_TRANSFER_ACK;
                            end
                        end
                    end
                endcase
            end

            DATA_TRANSFER_ACK: begin
                unique case (phase)
                    DRIVE: begin
                        // Release SDA for NACK (if read) / for slave to ACK (if write)
                        next_sda_drive_low = 1'b0;
                    end
                    RAISE: ; // IDLE
                    SAMPLE: begin
                        if (quarter_tick) begin
                            // Check for slave ACK
                            if (!rw_reg && sda_in) begin
                                next_error = 1'b1;
                            end
                        end
                    end
                    LOWER: begin
                        if (quarter_tick) begin
                            // Store data if read
                            if (rw_reg) begin
                                next_rx_data = rx_shift_reg;
                            end

                            if (error_reg) begin
                                next_state = STOP;
                            end
                            // Repeated START check
                            else if (repeated_start_reg) begin
                                next_state          = START;
                                next_repeated_start = 1'b0;

                                // Apply the buffered parameters
                                next_slave_addr = rstart_addr_reg;
                                next_rw         = rstart_rw_reg;
                                next_tx_data    = rstart_tx_data_reg;
                            end
                            else begin
                                next_state = STOP;
                            end
                        end
                    end
                endcase
            end

            STOP: begin
                unique case (phase)
                    DRIVE: begin
                        // SDA released, when SCL high to generate STOP.
                        next_sda_drive_low = 1'b1;
                    end
                    RAISE: ; // IDLE
                    SAMPLE: begin
                        next_sda_drive_low = 1'b0;
                    end
                    LOWER: begin
                        if (quarter_tick) begin
                            next_clock_enable   = 1'b0;
                            next_repeated_start = 1'b0;
                            next_busy           = 1'b0;
                            next_done           = 1'b1;
                            next_state          = IDLE;
                        end
                    end
                endcase
            end

            default: next_state = IDLE;
        endcase
    end

    // Registers
    always_ff @(posedge clk) begin
        if(!rst_n) begin
            state              <= IDLE;
            phase              <= DRIVE;
            slave_addr_reg     <= '0;
            rw_reg             <= 1'b0;
            tx_data_reg        <= '0;
            tx_shift_reg       <= '0;
            rx_data_reg        <= '0;
            rx_shift_reg       <= '0;
            busy_reg           <= 1'b0;
            done_reg           <= 1'b0;
            error_reg          <= 1'b0;
            scl_drive_low      <= 1'b0;
            sda_drive_low      <= 1'b0;
            bit_count          <= '0;
            divider_reg        <= '0;
            clock_enable       <= 1'b0;
            repeated_start_reg <= 1'b0;
            rstart_addr_reg    <= '0;
            rstart_rw_reg      <= 1'b0;
            rstart_tx_data_reg <= '0;
        end
        else begin
            state              <= next_state;
            phase              <= next_phase;
            slave_addr_reg     <= next_slave_addr;
            rw_reg             <= next_rw;
            tx_data_reg        <= next_tx_data;
            tx_shift_reg       <= next_tx_shift;
            rx_data_reg        <= next_rx_data;
            rx_shift_reg       <= next_rx_shift;
            busy_reg           <= next_busy;
            done_reg           <= next_done;
            error_reg          <= next_error;
            scl_drive_low      <= next_scl_drive_low;
            sda_drive_low      <= next_sda_drive_low;
            bit_count          <= next_bit_count;
            divider_reg        <= next_divider;
            clock_enable       <= next_clock_enable;
            repeated_start_reg <= next_repeated_start;
            rstart_addr_reg    <= next_rstart_addr;
            rstart_rw_reg      <= next_rstart_rw;
            rstart_tx_data_reg <= next_rstart_tx_data;
        end
    end

    // Output logic
    assign rx_data = rx_data_reg;
    assign busy    = busy_reg;
    assign done    = done_reg;
    assign error   = error_reg;

    // Bus interface
    assign scl = scl_drive_low ? 1'b0 : 1'bz;
    assign sda = sda_drive_low ? 1'b0 : 1'bz;

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
        if (DIVISOR <= 1) begin
            $error("CLOCK_FREQ_HZ must be at least four times SCL_FREQ_HZ.");
            error_check = 1;
        end
        if (CLOCK_FREQ_HZ <= SCL_FREQ_HZ) begin
            $error("CLOCK_FREQ_HZ must be greater than SCL_FREQ_HZ.");
            error_check = 1;
        end
        if (error_check) begin
            $fatal(0);
        end
    end

    // synthesis translate_on

endmodule
