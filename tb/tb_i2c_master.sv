`timescale 1ns/1ps

module tb_i2c_master;

    // Configuration parameters
    parameter int DATA_WIDTH    = 8;
    parameter int CLOCK_FREQ_HZ = 50_000_000;
    parameter int SCL_FREQ_HZ   = 100_000;

    // Parameters for reference and timing
    localparam time CLOCK_PERIOD_NS    = 10ns;
    localparam int RANDOM_ITERATIONS   = 100;
    localparam int CYCLES_PER_TRANSFER = (DATA_WIDTH * 2000) + 20;
    localparam int BASE_TEST_CYCLES    = 25 * CYCLES_PER_TRANSFER;
    localparam int TIMEOUT_CYCLES      = BASE_TEST_CYCLES+(RANDOM_ITERATIONS * CYCLES_PER_TRANSFER);
    localparam int RESET_CYCLES        = 3;
    localparam int STRETCH_CYCLES      = 5;

    // DUT signals
    logic                  clk;
    logic                  rst_n;
    logic                  start;
    logic [6:0]            slave_addr;
    logic                  rw;
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

    // Slave Reference Model signals
    logic                  slave_sda_drive_low;
    logic                  slave_scl_drive_low;
    logic [DATA_WIDTH-1:0] expected_rx_data;
    logic [DATA_WIDTH-1:0] slave_tx_data;
    logic [DATA_WIDTH-1:0] slave_rx_data;
    logic                  slave_addr_ack_enable;
    logic                  slave_data_ack_enable;
    logic                  slave_stretch_enable;
    logic [6:0]            expected_slave_addr;
    logic                  expected_rw;
    logic [DATA_WIDTH-1:0] received_byte;

    // Repeated START tracking
    int                    current_transaction_count;
    int                    force_nack_after_n;
    bit                    is_rstart;

    // Connection
    assign sda = slave_sda_drive_low ? 1'b0 : 1'bz;
    assign scl = slave_scl_drive_low ? 1'b0 : 1'bz;

    // DUT instantiation
    i2c_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .SCL_FREQ_HZ(SCL_FREQ_HZ)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .tx_data(tx_data),
        .rx_data(rx_data),
        .busy(busy),
        .done(done),
        .error(error),
        .sda(sda),
        .scl(scl)
    );

    // Assertions
    sva_i2c_master #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .SCL_FREQ_HZ(SCL_FREQ_HZ)
    ) sva (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
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
        $dumpfile("i2c_master_waveform.vcd");
        $dumpvars(0, tb_i2c_master);
    end

    // I2C Slave Behavioural Reference Model
    initial begin
        current_transaction_count = 0;
        force_nack_after_n = 0;
        forever begin
            wait_start();
            is_rstart = 1;
            while (is_rstart) begin
                slave_receive_byte(received_byte);
                if (received_byte[7:1] == expected_slave_addr) begin
                    current_transaction_count++;

                    // Force NACK to break repeated START sequences in test
                    if (force_nack_after_n>0 && current_transaction_count>=force_nack_after_n) begin
                        slave_nack();
                    end
                    else if (slave_addr_ack_enable) begin
                        if (slave_stretch_enable)
                            slave_clock_stretch(STRETCH_CYCLES);
                        slave_ack();

                        // Master write transaction
                        if (!received_byte[0]) begin
                            slave_receive_byte(slave_rx_data);
                            if (slave_data_ack_enable) begin
                                if (slave_stretch_enable)
                                    slave_clock_stretch(STRETCH_CYCLES);
                                slave_ack();
                            end
                            else
                                slave_nack();
                        end
                        // Master read transaction
                        else begin
                            slave_send_byte(slave_tx_data);
                        end
                    end
                    else begin
                        slave_nack();
                    end
                end
                else begin
                    slave_nack();
                end

                wait_for_stop_or_rstart(is_rstart);
            end
        end
    end

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
            // Apply Reset
            rst_n      = 1'b0;
            start      = 1'b0;
            slave_addr = '0;
            rw         = 1'b0;
            tx_data    = '0;

            // Reset slave reference model
            slave_sda_drive_low       = 1'b0;
            slave_scl_drive_low       = 1'b0;
            slave_addr_ack_enable     = 1'b1;
            slave_data_ack_enable     = 1'b1;
            slave_stretch_enable      = 1'b0;
            expected_slave_addr       = '0;
            expected_rw               = 1'b0;
            expected_rx_data          = '0;
            slave_tx_data             = '0;
            slave_rx_data             = '0;
            current_transaction_count = 0;
            force_nack_after_n        = 0;

            // Hold reset
            repeat(RESET_CYCLES) @(posedge clk);

            // Release reset
            rst_n = 1'b1;

            @(posedge clk);
        end
    endtask

    // Wait until transaction completes
    task automatic wait_done;
    begin
        wait(done == 1'b0);
        wait(done);
        repeat(3) @(posedge clk);
    end
    endtask

    // Wait until error triggered or transaction completes
    task automatic wait_done_or_error;
    begin
        wait(done == 1'b0 && error == 1'b0);
        wait(done || error);
        repeat(3) @(posedge clk);
    end
    endtask

    // Start a master transaction
    task automatic start_transaction(
        input logic [6:0]            addr,
        input logic                  operation,
        input logic [DATA_WIDTH-1:0] data
    );
    begin
        @(posedge clk);

        slave_addr = addr;
        rw         = operation;
        tx_data    = data;

        expected_slave_addr = addr;
        expected_rw         = operation;
        expected_rx_data    = data;

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;
    end
    endtask

    // Wait for START condition
    task automatic wait_start;
        bit start_detected;
    begin
        start_detected = 1'b0;
        while (!start_detected) begin
            @(negedge sda);
            if (scl === 1'b1) begin
                start_detected = 1'b1;
            end
        end
        // Synchronization
        @(negedge scl);
    end
    endtask

    // Wait for STOP or Repeated START condition
    task automatic wait_for_stop_or_rstart(output bit is_rstart);
        bit condition_met;
    begin
        condition_met = 1'b0;
        is_rstart = 1'b0;
        while (!condition_met) begin
            @(sda);
            if (scl === 1'b1) begin
                if (sda === 1'b1) begin
                    is_rstart = 1'b0; // STOP detected
                    condition_met = 1'b1;
                end else if (sda === 1'b0) begin
                    is_rstart = 1'b1; // Repeated START detected
                    condition_met = 1'b1;
                end
            end
        end
    end
    endtask

    // Receive one byte from master (MSB first)
    task automatic slave_receive_byte(output logic [DATA_WIDTH-1:0] data);
        int i;
        begin
            data = '0;
            for (i = DATA_WIDTH-1; i >= 0; i--) begin
                @(posedge scl);
                data[i] = sda;
                @(negedge scl);
            end
        end
    endtask

    // Send one byte to master (MSB first)
    task automatic slave_send_byte(input logic [DATA_WIDTH-1:0] data);
        int i;
        begin
            for (i = DATA_WIDTH-1; i >= 0; i--) begin
                slave_sda_drive_low = ~data[i];
                @(posedge scl);
                @(negedge scl);
            end
            slave_sda_drive_low = 1'b0;
        end
    endtask

    // Slave sends ACK
    task automatic slave_ack;
    begin
        slave_sda_drive_low = 1'b1;
        @(posedge scl);
        @(negedge scl);
        slave_sda_drive_low = 1'b0;
    end
    endtask

    // Slave sends NACK
    task automatic slave_nack;
    begin
        slave_sda_drive_low = 1'b0;
        @(posedge scl);
        @(negedge scl);
    end
    endtask

    // Slave clock stretch
    task automatic slave_clock_stretch(input int cycles);
    begin
        slave_scl_drive_low = 1'b1;
        repeat(cycles) @(posedge clk);
        slave_scl_drive_low <= 1'b0;
    end
    endtask

    // Check I2C returns to idle after transaction
    task automatic check_idle_state;
        begin
            record_test("Idle State",
                busy    == 1'b0 &&
                sda     === 1'b1 &&
                scl     === 1'b1
            );
        end
    endtask

    // Print Summary
    task automatic print_summary;
        begin

            $display("\n==================================================");
            $display("             I2C MASTER TEST SUMMARY");
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
    task automatic test_reset();
    begin
        $display("\n=== Reset Behaviour Test ===");
        apply_reset();
        check_idle_state();
    end
    endtask

    // Test write behaviour
    task automatic test_write;
    begin
        $display("\n=== Write Transaction Test ===");
        apply_reset();

        start_transaction(7'h42, 1'b0, 8'hA5);
        wait_done();

        record_test("Write", !error);
        record_test("Slave Address", received_byte[7:1] == expected_slave_addr);
        record_test("Written Data", slave_rx_data == expected_rx_data);
        record_test("Busy Cleared", !busy);
        record_test("Bus Released", sda === 1'b1 && scl === 1'b1);
    end
    endtask

    // Test read behaviour
    task automatic test_read();
    begin
        $display("\n=== Read Transaction Test ===");
        apply_reset();
        slave_tx_data = 8'h3C;

        start_transaction(7'h5A, 1'b1, 8'h00);
        wait_done();

        record_test("Read rx_data == 8'h3C", rx_data == 8'h3C);
        record_test("Read without error", error == 1'b0);
        check_idle_state();
    end
    endtask

    // Address NACK test
    task automatic test_address_nack();
    begin
        $display("\n=== Address NACK Test ===");
        apply_reset();
        slave_addr_ack_enable = 1'b0;

        start_transaction(7'h2B, 1'b0, 8'hFF);

        wait_done_or_error(); // Triggers as soon as NACK creates error
        record_test("error == 1", error == 1'b1);
        record_test("done == 0 (at exact time error triggers)", done == 1'b0);

        wait_done(); // Wait for actual STOP phase to resolve and bus to release
        check_idle_state();
    end
    endtask

    // Data NACK test
    task automatic test_data_nack();
    begin
        $display("\n=== Data NACK Test ===");
        apply_reset();
        slave_addr_ack_enable = 1'b1;
        slave_data_ack_enable = 1'b0;

        start_transaction(7'h3C, 1'b0, 8'hAA);
        wait_done_or_error();

        record_test("Master detects NACK and asserts error", error == 1'b1);
        wait_done();
        check_idle_state();
    end
    endtask

    // Clock Stretching Test
    task automatic test_clock_stretching();
    begin
        $display("\n=== Clock Stretching Test ===");
        apply_reset();
        slave_stretch_enable = 1'b1;

        // Run a write transaction
        start_transaction(7'h4D, 1'b0, 8'h55);
        wait_done();
        record_test("Stretched Write Completed correctly", error == 1'b0 && slave_rx_data == 8'h55);

        // Run a read transaction
        slave_tx_data = 8'hAA;
        start_transaction(7'h4D, 1'b1, 8'h00);
        wait_done();
        record_test("Stretched Read Completed correctly", error == 1'b0 && rx_data == 8'hAA);

        check_idle_state();
    end
    endtask

    // Repeated START test
    task automatic test_repeated_start();
    begin
        $display("\n=== Repeated START Test ===");
        apply_reset();

        start_transaction(7'h12, 1'b0, 8'h34);
        wait(busy);
        @(posedge clk);

        // Issue Repeated START
        slave_addr    = 7'h12;
        rw            = 1'b1;  // Change direction to Read
        tx_data       = 8'h00;
        slave_tx_data = 8'h99;

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for transaction to end
        wait_done();
        record_test("No error during back-to-back sequence", error == 1'b0);
        record_test("Slave correctly received Write Data", slave_rx_data == 8'h34);
        record_test("Master successfully read data via Sr", rx_data == 8'h99);

        check_idle_state();
    end
    endtask

    // Random Stress Test
    task automatic test_random_transfers();
        logic [6:0] rand_addr;
        logic       rand_rw;
        logic [7:0] rand_data;
        bit         pass_flag;
    begin
        $display("\n=== Random Transfer Test (%0d iterations) ===", RANDOM_ITERATIONS);
        apply_reset();
        pass_flag = 1'b1;

        for (int i = 0; i < RANDOM_ITERATIONS; i++) begin
            rand_addr = $urandom;
            rand_rw   = $urandom; // 0 = read, 1 = write
            rand_data = $urandom;

            // Randomize stretching and inject NACKs (approx. 10% chance to NACK)
            slave_stretch_enable  = $urandom_range(0, 1);
            slave_addr_ack_enable = ($urandom_range(0, 9) != 0);
            slave_data_ack_enable = ($urandom_range(0, 9) != 0);

            slave_tx_data = $urandom;
            start_transaction(rand_addr, rand_rw, rand_data);

            // Wait for completion
            wait_done();

            if (!slave_addr_ack_enable) begin
                if (error !== 1'b1) pass_flag = 1'b0;
            end
            else if (!rand_rw && !slave_data_ack_enable) begin // slave_data_ack only impacts writes
                if (error !== 1'b1) pass_flag = 1'b0;
            end
            else begin
                if (error !== 1'b0) pass_flag = 1'b0;
                if (rand_rw && rx_data !== slave_tx_data) pass_flag = 1'b0;
            end

            // Reseed guarantees ACKs for loop reset
            slave_addr_ack_enable = 1'b1;
            slave_data_ack_enable = 1'b1;
        end
        record_test("Random Stress Tests Completed", pass_flag);
    end
    endtask

    // Test tasks end
    // --------------

    // Main test sequence
    initial begin
        test_reset();
        test_write();
        test_read();
        test_address_nack();
        test_data_nack();
        test_clock_stretching();
        test_repeated_start();
        test_random_transfers();

        print_summary();
        $finish;
    end


endmodule
