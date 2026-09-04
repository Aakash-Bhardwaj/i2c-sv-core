`timescale 1ns/1ps

module tb_i2c_top;

    // Configuration parameters
    parameter int         DATA_WIDTH     = 8;
    parameter int         CLOCK_FREQ_HZ  = 50_000_000;
    parameter int         SCL_FREQ_HZ    = 100_000;
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
    logic                  start;
    logic [6:0]            slave_addr;
    logic                  rw;
    logic [DATA_WIDTH-1:0] master_tx_data;
    logic [DATA_WIDTH-1:0] master_rx_data;
    logic                  master_busy;
    logic                  master_done;
    logic                  master_error;
    logic [DATA_WIDTH-1:0] slave_tx_data;
    logic [DATA_WIDTH-1:0] slave_rx_data;
    logic                  slave_busy;
    logic                  slave_done;
    logic                  slave_error;
    tri1                   sda;
    tri1                   scl;

    // Verification statistics
    int tests_run    = 0;
    int tests_passed = 0;
    int tests_failed = 0;

    // Pull-up resistors for the I2C buses
    pullup(sda);
    pullup(scl);

    // DUT instantiation
    i2c_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .SCL_FREQ_HZ(SCL_FREQ_HZ),
        .SLAVE_ADDR(SLAVE_ADDR),
        .STRETCH_CYCLES(STRETCH_CYCLES)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .master_tx_data(master_tx_data),
        .master_rx_data(master_rx_data),
        .master_busy(master_busy),
        .master_done(master_done),
        .master_error(master_error),
        .slave_tx_data(slave_tx_data),
        .slave_rx_data(slave_rx_data),
        .slave_busy(slave_busy),
        .slave_done(slave_done),
        .slave_error(slave_error),
        .sda(sda),
        .scl(scl)
    );

    // Assertions
    sva_i2c_top #(
        .DATA_WIDTH(DATA_WIDTH),
        .CLOCK_FREQ_HZ(CLOCK_FREQ_HZ),
        .SCL_FREQ_HZ(SCL_FREQ_HZ),
        .SLAVE_ADDR(SLAVE_ADDR),
        .STRETCH_CYCLES(STRETCH_CYCLES)
    ) sva (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .slave_addr(slave_addr),
        .rw(rw),
        .master_tx_data(master_tx_data),
        .master_rx_data(master_rx_data),
        .master_busy(master_busy),
        .master_done(master_done),
        .master_error(master_error),
        .slave_tx_data(slave_tx_data),
        .slave_rx_data(slave_rx_data),
        .slave_busy(slave_busy),
        .slave_done(slave_done),
        .slave_error(slave_error),
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
        $dumpfile("i2c_top_waveform.vcd");
        $dumpvars(0, tb_i2c_top);
    end

    // ------------
    // Helper tasks

    // Hardware pulse catcher for Icarus Verilog compatibility
    bit slave_done_caught;
    always @(posedge clk) begin
        if (start)
            slave_done_caught <= 1'b0; // Reset flag on new transaction
        else if (slave_done)
            slave_done_caught <= 1'b1; // Catch the 1-cycle pulse
    end

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
        rst_n          = 1'b0;
        start          = 1'b0;
        slave_addr     = '0;
        rw             = 1'b0;
        master_tx_data = '0;
        slave_tx_data  = '0;

        repeat(RESET_CYCLES) @(posedge clk);
        rst_n = 1'b1;
        @(posedge clk);
    end
    endtask

    // Execute a Master transaction
    task automatic execute_transaction(
        input logic [6:0]            addr,
        input logic                  read_write,
        input logic [DATA_WIDTH-1:0] tx_data,
        output bit                   s_done
    );
    begin
        s_done = 1'b0;

        slave_addr     = addr;
        rw             = read_write;
        master_tx_data = read_write ? master_tx_data : tx_data;
        slave_tx_data  = read_write ? tx_data : slave_tx_data;

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for done
        wait(master_done);

        repeat(2) @(posedge clk);
        s_done = slave_done_caught;
    end
    endtask

    // Check if buses are idle
    task automatic check_bus_idle(output bit idle);
    begin
        idle = (sda === 1'b1) && (scl === 1'b1);
    end
    endtask

    // Print Summary
    task automatic print_summary;
        begin

            $display("\n==================================================");
            $display("             I2C TOP TEST SUMMARY");
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

    // Test reset and idle behaviour
    task automatic test_reset_idle;
        bit bus_idle;
    begin
        $display("\n=== Reset / Idle Test ===");
        apply_reset();
        check_bus_idle(bus_idle);

        record_test("Master Not Busy", !master_busy);
        record_test("Slave Not Busy", !slave_busy);
        record_test("Bus Idle (SDA/SCL High)", bus_idle);
    end
    endtask

    // Test master write and slave read
    task automatic test_master_write;
        bit s_done;
    begin
        $display("\n=== Master Write / Slave Read Test ===");
        apply_reset();

        execute_transaction(SLAVE_ADDR, 1'b0, 8'hA5, s_done);

        record_test("Slave Completed", s_done);
        record_test("No Master Error", !master_error);
        record_test("Slave Received Correct Data (8'hA5)", slave_rx_data === 8'hA5);
    end
    endtask

    // Test master read and slave write
    task automatic test_master_read;
        bit s_done;
    begin
        $display("\n=== Master Read / Slave Write Test ===");
        apply_reset();

        execute_transaction(SLAVE_ADDR, 1'b1, 8'h3C, s_done);

        record_test("Slave Completed", s_done);
        record_test("No Master Error", !master_error);
        record_test("Master Received Correct Data (8'h3C)", master_rx_data === 8'h3C);
    end
    endtask

    // Test address mismatch behaviour
    task automatic test_address_mismatch;
        bit s_done;
    begin
        $display("\n=== Address Mismatch / NACK Test ===");
        apply_reset();

        // Attempt a transaction with an unregistered address (7'h11)
        execute_transaction(7'h11, 1'b0, 8'hFF, s_done);

        record_test("Slave Did NOT Complete (Safely Ignored)", !s_done);
        record_test("Master Detected NACK Error", master_error === 1'b1);
    end
    endtask

    // Test repeated start behaviour
    task automatic test_repeated_start;
        bit s_done;
    begin
        $display("\n=== Repeated START Test ===");
        apply_reset();
        s_done = 1'b0;

        // 1st Transaction (Write)
        slave_addr     = SLAVE_ADDR;
        rw             = 1'b0;
        master_tx_data = 8'h77;

        @(posedge clk);
        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        // Wait for 1st transaction to start
        wait(master_busy);
        @(posedge clk);

        // 2nd Transaction (Read)
        slave_addr     = SLAVE_ADDR;
        rw             = 1'b1;      // Change direction to Read
        slave_tx_data  = 8'h99;

        start = 1'b1;
        @(posedge clk);
        start = 1'b0;

        wait(master_done);
        repeat(2) @(posedge clk);
        s_done = slave_done_caught;
        repeat(3) @(posedge clk);

        record_test("No Master Error across both loops", !master_error);
        record_test("Slave Completed Back-To-Back sequence", s_done);
        record_test("Slave correctly received Write Data", slave_rx_data === 8'h77);
        record_test("Master correctly Read Data via Sr", master_rx_data === 8'h99);
    end
    endtask

    // Test clock stretching behaviour
    task automatic test_clock_stretching;
        bit s_done;
    begin
        $display("\n=== Clock Stretching Test ===");
        apply_reset();

        execute_transaction(SLAVE_ADDR, 1'b0, 8'h88, s_done);

        record_test("Stretched Write Passed", s_done && !master_error && slave_rx_data === 8'h88);
    end
    endtask

    // Deterministic patterns test
    task automatic test_deterministic_patterns;
        bit s_done;
        logic [DATA_WIDTH-1:0] patterns [4];
    begin
        $display("\n=== Deterministic Data Patterns Test ===");
        apply_reset();

        patterns[0] = 8'h00;
        patterns[1] = 8'hFF;
        patterns[2] = 8'h55;
        patterns[3] = 8'hAA;

        for (int i = 0; i < $size(patterns); i++) begin
            // Write to Slave
            execute_transaction(SLAVE_ADDR, 1'b0, patterns[i], s_done);
            record_test($sformatf("Pattern %h Written", patterns[i]), s_done && slave_rx_data === patterns[i]);

            // Read from Slave
            execute_transaction(SLAVE_ADDR, 1'b1, patterns[i], s_done);
            record_test($sformatf("Pattern %h Read", patterns[i]), s_done && master_rx_data === patterns[i]);
        end
    end
    endtask

    // Random Stress Test
    task automatic test_random_stress;
        bit s_done;
        bit pass_flag;
        logic [6:0] rand_addr;
        logic       rand_rw;
        logic [7:0] rand_data;
    begin
        $display("\n=== Random Stress Test (%0d iterations) ===", RANDOM_ITERATIONS);
        apply_reset();
        pass_flag = 1'b1;

        for (int i = 0; i < RANDOM_ITERATIONS; i++) begin

            // Bias address generation heavily towards correct address (90% hit rate)
            if ($urandom_range(0, 9) != 0) rand_addr = SLAVE_ADDR;
            else                           rand_addr = $urandom;

            rand_rw   = $urandom;
            rand_data = $urandom;

            execute_transaction(rand_addr, rand_rw, rand_data, s_done);

            if (rand_addr !== SLAVE_ADDR) begin
                if (!master_error) pass_flag = 1'b0;
                if (s_done) pass_flag = 1'b0;
            end
            else begin
                if (master_error) pass_flag = 1'b0;
                if (!s_done) pass_flag = 1'b0;

                if (rand_rw == 1'b0 && slave_rx_data !== rand_data) pass_flag = 1'b0;
                if (rand_rw == 1'b1 && master_rx_data !== rand_data) pass_flag = 1'b0;
            end
        end
        record_test("Random Stress Tests Completed Successfully", pass_flag);
    end
    endtask

    // Test tasks end
    // --------------

    // Main test sequence
    initial begin
        test_reset_idle();
        test_master_write();
        test_master_read();
        test_address_mismatch();
        test_repeated_start();
        test_clock_stretching();
        test_deterministic_patterns();
        test_random_stress();

        print_summary();
        $finish;
    end

endmodule
