`timescale 1ns/1ps

module tb_i2c_slave;

    // Configuration parameters
    parameter int         DATA_WIDTH     = 8;
    parameter logic [6:0] SLAVE_ADDR     = 7'h42;
    parameter int         STRETCH_CYCLES = 5;

    // Parameters for reference and timing
    localparam time CLOCK_PERIOD_NS    = 10ns;
    localparam time I2C_DELAY          = 1000ns;
    localparam int RANDOM_ITERATIONS   = 100;
    localparam int CYCLES_PER_TRANSFER = (DATA_WIDTH * 2000) + 20;
    localparam int BASE_TEST_CYCLES    = 250 * CYCLES_PER_TRANSFER;
    localparam int TIMEOUT_CYCLES      = BASE_TEST_CYCLES + (RANDOM_ITERATIONS * CYCLES_PER_TRANSFER);
    localparam int RESET_CYCLES        = 3;

    // DUT signals
    logic                  clk;
    logic                  rst_n;
    logic [DATA_WIDTH-1:0] tx_data;
    logic [DATA_WIDTH-1:0] rx_data;
    logic                  busy;
    logic                  done;
    logic                  error;
    tri1                   sda;
    tri1                   scl;

    // Verification statistics
    int tests_run    = 0;
    int tests_passed = 0;
    int tests_failed = 0;

    // Master Reference Model signals
    logic                  master_sda_drive_low;
    logic                  master_scl_drive_low;

    // Connection
    assign sda = master_sda_drive_low ? 1'b0 : 1'bz;
    assign scl = master_scl_drive_low ? 1'b0 : 1'bz;

    // DUT instantiation
    i2c_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_ADDR(SLAVE_ADDR),
        .STRETCH_CYCLES(STRETCH_CYCLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .error(error),
        .sda(sda),
        .scl(scl)
    );

    // Assertions
    sva_i2c_slave #(
        .DATA_WIDTH(DATA_WIDTH),
        .SLAVE_ADDR(SLAVE_ADDR),
        .STRETCH_CYCLES(STRETCH_CYCLES)
    ) sva (
        .clk(clk),
        .rst_n(rst_n),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .error(error),
        .sda(sda),
        .scl(scl)
    );

    // Clock generation
    initial clk = 1'b0;
    always #(CLOCK_PERIOD_NS/2.0) clk = ~clk;

    // Timeout watchdog
    initial begin
        repeat(TIMEOUT_CYCLES) @(posedge clk);
        $fatal(1,"[TIMEOUT] Simulation hung! Watchdog triggered after %0d cycles.", TIMEOUT_CYCLES);
    end

    // Waveform generation
    initial begin
        $dumpfile("i2c_slave_waveform.vcd");
        $dumpvars(0, tb_i2c_slave);
    end

    // ---------------------------
    // Master reference model tasks

    // Wait for SCL
    task automatic master_wait_scl_high;
    begin
        master_scl_drive_low = 1'b0; // Release SCL
        @(posedge scl);              // Wait for SCL to actually go high (Dynamically handles DUT clock stretching)
        #(I2C_DELAY);                // Wait high time
    end
    endtask

    // Start master reference model
    task automatic master_start;
    begin
        master_sda_drive_low = 1'b0;
        master_scl_drive_low = 1'b0; // Idle state
        #(I2C_DELAY);
        master_sda_drive_low = 1'b1; // SDA goes low (START)
        #(I2C_DELAY);
        master_scl_drive_low = 1'b1; // SCL goes low
        #(I2C_DELAY);
    end
    endtask

    // Stop master reference model
    task automatic master_stop;
    begin
        master_scl_drive_low = 1'b1; // Ensure SCL low
        master_sda_drive_low = 1'b1; // Ensure SDA low
        #(I2C_DELAY);
        master_scl_drive_low = 1'b0; // Release SCL
        @(posedge scl);
        #(I2C_DELAY);
        master_sda_drive_low = 1'b0; // Release SDA (STOP)
        #(I2C_DELAY);
    end
    endtask

    // Send bits from master reference model
    task automatic master_send_bit(input logic bit_val);
    begin
        master_scl_drive_low = 1'b1; // SCL low
        #(I2C_DELAY);
        master_sda_drive_low = ~bit_val; // Drive data
        #(I2C_DELAY);
        master_wait_scl_high();
        master_scl_drive_low = 1'b1; // Pull SCL low to end bit
        #(I2C_DELAY);
    end
    endtask

    // Receive bits at master reference model
    task automatic master_receive_bit(output logic bit_val);
    begin
        master_scl_drive_low = 1'b1; // SCL low
        master_sda_drive_low = 1'b0; // Release SDA for slave to drive
        #(I2C_DELAY);
        master_wait_scl_high();
        bit_val = sda;               // Sample SDA
        master_scl_drive_low = 1'b1; // Pull SCL low to end bit
        #(I2C_DELAY);
    end
    endtask

    // Send bytes from master reference model
    task automatic master_send_byte(input logic [DATA_WIDTH-1:0] data, output logic ack);
        int i;
    begin
        for (i = DATA_WIDTH-1; i >= 0; i--) begin
            master_send_bit(data[i]);
        end
        master_receive_bit(ack); // 0 = ACK, 1 = NACK
    end
    endtask

    // Receive bytes at master reference model
    task automatic master_receive_byte(output logic [DATA_WIDTH-1:0] data, input logic send_ack);
        int i;
        logic bit_val;
    begin
        data = '0;
        for (i = DATA_WIDTH-1; i >= 0; i--) begin
            master_receive_bit(bit_val);
            data[i] = bit_val;
        end
        master_send_bit(~send_ack); // send_ack: 1 means ACK (0 on bus), 0 means NACK (1 on bus)
    end
    endtask

    // Master reference model tasks end
    // --------------------------------

    // ------------
    // Helper tasks

    // Record test results
    task automatic record_test(input string test_name, input bit passed);
        begin
            tests_run++;
            if (passed) begin
                tests_passed++;
                $display("[PASS] %s", test_name);
            end else begin
                tests_failed++;
                $error("[FAIL] %s", test_name);
            end
        end
    endtask

    // Apply reset
    task automatic apply_reset;
    begin
        rst_n                = 1'b0;
        tx_data              = '0;
        master_sda_drive_low = 1'b0;
        master_scl_drive_low = 1'b0;

        repeat(RESET_CYCLES) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    end
    endtask

    // Wait for done
    task automatic wait_done;
    begin
        wait(done == 1'b0);
        wait(done);
        repeat(3) @(posedge clk);
    end
    endtask

    // Print Summary
    task automatic print_summary;
        begin

            $display("\n==================================================");
            $display("             I2C SLAVE TEST SUMMARY");
            $display("==================================================");

            $display("Tests Run    : %0d", tests_run);
            $display("Tests Passed : %0d", tests_passed);
            $display("Tests Failed : %0d", tests_failed);

            if (tests_failed == 0)
                $display("OVERALL RESULT : PASS");
            else
                $display("OVERALL RESULT : FAIL");

            $display("==================================================");

        end
    endtask

    // Helper tasks end
    // ----------------

    // ----------
    // Test tasks

    // Test reset behaviour
    task automatic test_reset;
    begin
        $display("\n=== Reset Behaviour Test ===");
        apply_reset();
        record_test("Idle State", !busy && !done && sda === 1'b1 && scl === 1'b1);
    end
    endtask

    // Test slave behaviour when master writes
    task automatic test_master_write;
        logic ack;
    begin
        $display("\n=== Master Write Transaction Test ===");
        apply_reset();

        master_start();
        master_send_byte({SLAVE_ADDR, 1'b0}, ack);
        record_test("Address ACK received", ack === 1'b0);
        record_test("Busy Asserts on Start", busy === 1'b1);

        master_send_byte(8'hA5, ack);
        record_test("Data ACK received", ack === 1'b0);

        fork
            master_stop();
            wait_done();
        join

        record_test("DUT received correct data (rx_data == 8'hA5)", rx_data === 8'hA5);
        record_test("DUT done asserted properly", done === 1'b0);
    end
    endtask

    // Test slave behaviour when master reads
    task automatic test_master_read;
        logic ack;
        logic [DATA_WIDTH-1:0] read_data;
    begin
        $display("\n=== Master Read Transaction Test ===");
        apply_reset();

        tx_data = 8'h3C; // Preload data for slave to transmit

        master_start();
        master_send_byte({SLAVE_ADDR, 1'b1}, ack); // Issue read command
        record_test("Address ACK received", ack === 1'b0);

        master_receive_byte(read_data, 1'b0); // Read byte, send NACK to end transfer

        fork
            master_stop();
            wait_done();
        join

        record_test("Master read correct data from slave (read_data == 8'h3C)", read_data === 8'h3C);
    end
    endtask

    // Test address mismatch behaviour
    task automatic test_address_mismatch;
        logic ack;
    begin
        $display("\n=== Address Mismatch / NACK Test ===");
        apply_reset();

        master_start();
        master_send_byte({7'h11, 1'b0}, ack); // Incorrect address
        record_test("Address NACK received by Master (Correct)", ack === 1'b1);
        master_stop();

        repeat(5) @(posedge clk);
        record_test("DUT properly ignored transmission", done === 1'b0 && busy === 1'b0);
    end
    endtask

    // Test Repeated START behaviour
    task automatic test_repeated_start;
        logic ack;
        logic [DATA_WIDTH-1:0] read_data;
    begin
        $display("\n=== Repeated START Test ===");
        apply_reset();

        tx_data = 8'h99; // Preload data for the read phase

        // 1st Transaction: Master Write
        master_start();
        master_send_byte({SLAVE_ADDR, 1'b0}, ack);
        record_test("Write Addr ACK", ack === 1'b0);

        master_send_byte(8'hAA, ack);
        record_test("Write Data ACK", ack === 1'b0);

        // DELIBERATELY OMIT master_stop() HERE
        // Issue Repeated START directly
        master_start();

        // 2nd Transaction: Master Read
        master_send_byte({SLAVE_ADDR, 1'b1}, ack);
        record_test("Read Addr ACK (Repeated Start)", ack === 1'b0);

        master_receive_byte(read_data, 1'b0); // Read byte, send NACK

        // Stop and trap the done pulse
        fork
            master_stop();
            wait_done();
        join

        record_test("DUT received correct write data", rx_data === 8'hAA);
        record_test("Master read correct data via Sr", read_data === 8'h99);
    end
    endtask

    // Random Stress Test
    task automatic test_random_transfers;
        logic ack;
        logic [DATA_WIDTH-1:0] rand_data, read_data;
        logic rand_rw;
        bit pass_flag;
    begin
        $display("\n=== Random Stress Test (%0d iterations) ===", RANDOM_ITERATIONS);
        apply_reset();
        pass_flag = 1'b1;

        for (int i = 0; i < RANDOM_ITERATIONS; i++) begin
            rand_rw   = $urandom; // 0 = Write, 1 = Read
            rand_data = $urandom;

            tx_data = rand_data; // Pre-load for read

            master_start();
            master_send_byte({SLAVE_ADDR, rand_rw}, ack);

            if (ack !== 1'b0) pass_flag = 1'b0;

            // Master write
            if (rand_rw == 1'b0) begin
                master_send_byte(rand_data, ack);
                if (ack !== 1'b0) pass_flag = 1'b0;
            end
            // Master Read
            else begin
                master_receive_byte(read_data, 1'b0); // Read and NACK
                if (read_data !== rand_data) pass_flag = 1'b0;
            end

            fork
                master_stop();
                if (ack === 1'b0) wait_done(); // Only expect 'done' if the slave answered its address
            join
        end
        record_test("Random Stress Tests Completed Successfully", pass_flag);
    end
    endtask

    // Test tasks end
    // --------------

    // Main test sequence
    initial begin
        test_reset();
        test_master_write(); // Will inherently test clock stretching as well if STRETCH_CYCLES > 0
        test_master_read();
        test_address_mismatch();
        test_repeated_start();
        test_random_transfers();

        print_summary();
        $finish;
    end

endmodule
