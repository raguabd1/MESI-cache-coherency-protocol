`timescale 1ns/1ps
// minimum I should run this testbench for 5-6 us.
module mesi_tb;

    // Clock and Reset
    reg clk;
    reg rst_n;
    
    // Core 0 Interface
    reg [31:0] cpu0_addr;
    reg [31:0] cpu0_wdata;
    reg [1:0] cpu0_op;
    wire [31:0] cpu0_rdata;
    wire cpu0_ready;
    
    // Core 1 Interface
    reg [31:0] cpu1_addr;
    reg [31:0] cpu1_wdata;
    reg [1:0] cpu1_op;
    wire [31:0] cpu1_rdata;
    wire cpu1_ready;
    
    // Operation codes
    localparam NOP = 2'b00;
    localparam RD = 2'b01;
    localparam WR = 2'b10;
    
    // Test control
    integer test_num;
    integer errors;
    
    // DUT instantiation
    mesi_top dut (
        .clk(clk),
        .rst_n(rst_n),
        .cpu0_addr(cpu0_addr),
        .cpu0_wdata(cpu0_wdata),
        .cpu0_op(cpu0_op),
        .cpu0_rdata(cpu0_rdata),
        .cpu0_ready(cpu0_ready),
        .cpu1_addr(cpu1_addr),
        .cpu1_wdata(cpu1_wdata),
        .cpu1_op(cpu1_op),
        .cpu1_rdata(cpu1_rdata),
        .cpu1_ready(cpu1_ready)
    );
    
    // Clock generation
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end
    
    // Initialize signals
    task initialize;
        begin
            cpu0_addr = 32'h0;
            cpu0_wdata = 32'h0;
            cpu0_op = NOP;
            cpu1_addr = 32'h0;
            cpu1_wdata = 32'h0;
            cpu1_op = NOP;
            test_num = 0;
            errors = 0;
        end
    endtask
    
    // Reset task
    task reset_system;
        begin
            rst_n = 0;
            initialize();
            repeat(5) @(posedge clk);
            rst_n = 1;
            repeat(2) @(posedge clk);
            $display("=== System Reset Complete ===");
        end
    endtask
    
    // Wait for ready
    task wait_ready_core0;
        begin
            while (!cpu0_ready) @(posedge clk);
            @(posedge clk);
        end
    endtask
    
    task wait_ready_core1;
        begin
            while (!cpu1_ready) @(posedge clk);
            @(posedge clk);
        end
    endtask
    
    // Core 0 Read
    task core0_read(input [31:0] addr);
        begin
            cpu0_addr = addr;
            cpu0_op = RD;
            @(posedge clk);
            wait_ready_core0();
            cpu0_op = NOP;
            $display("[%0t] Core0 READ  addr=0x%h data=0x%h", $time, addr, cpu0_rdata);
        end
    endtask
    
    // Core 0 Write
    task core0_write(input [31:0] addr, input [31:0] data);
        begin
            cpu0_addr = addr;
            cpu0_wdata = data;
            cpu0_op = WR;
            @(posedge clk);
            wait_ready_core0();
            cpu0_op = NOP;
            $display("[%0t] Core0 WRITE addr=0x%h data=0x%h", $time, addr, data);
        end
    endtask
    
    // Core 1 Read
    task core1_read(input [31:0] addr);
        begin
            cpu1_addr = addr;
            cpu1_op = RD;
            @(posedge clk);
            wait_ready_core1();
            cpu1_op = NOP;
            $display("[%0t] Core1 READ  addr=0x%h data=0x%h", $time, addr, cpu1_rdata);
        end
    endtask
    
    // Core 1 Write
    task core1_write(input [31:0] addr, input [31:0] data);
        begin
            cpu1_addr = addr;
            cpu1_wdata = data;
            cpu1_op = WR;
            @(posedge clk);
            wait_ready_core1();
            cpu1_op = NOP;
            $display("[%0t] Core1 WRITE addr=0x%h data=0x%h", $time, addr, data);
        end
    endtask
    
    // Check data
    task check_data(input [31:0] expected, input [31:0] actual, input [7:0] core_id);
        begin
            if (expected !== actual) begin
                $display("ERROR: Core%0d - Expected 0x%h, Got 0x%h", core_id, expected, actual);
                errors = errors + 1;
            end else begin
                $display("PASS: Core%0d - Data matched: 0x%h", core_id, actual);
            end
        end
    endtask
    
    // Main test sequence
    initial begin
        $display("\n");
        $display("========================================");
        $display("   MESI Protocol Testbench Starting    ");
        $display("========================================\n");
        
        // Initialize
        reset_system();
        
        // ====================================================================
        // TEST 1: Simple Read Miss - Core 0
        // ====================================================================
        test_num = 1;
        $display("\n--- TEST %0d: Core0 Read Miss (I->E transition) ---", test_num);
        core0_read(32'h0000_1000);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 2: Read Hit - Core 0
        // ====================================================================
        test_num = 2;
        $display("\n--- TEST %0d: Core0 Read Hit ---", test_num);
        core0_read(32'h0000_1000);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 3: Write Hit - Core 0 (E->M transition)
        // ====================================================================
        test_num = 3;
        $display("\n--- TEST %0d: Core0 Write Hit (E->M transition) ---", test_num);
        core0_write(32'h0000_1000, 32'hDEADBEEF);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 4: Read after Write - Core 0
        // ====================================================================
        test_num = 4;
        $display("\n--- TEST %0d: Core0 Read after Write ---", test_num);
        core0_read(32'h0000_1000);
        check_data(32'hDEADBEEF, cpu0_rdata, 0);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 5: Write Miss - Core 1 (I->M transition)
        // ====================================================================
        test_num = 5;
        $display("\n--- TEST %0d: Core1 Write Miss (I->M transition) ---", test_num);
        core1_write(32'h0000_2000, 32'hCAFEBABE);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 6: Cache Coherence - Core1 reads what Core0 wrote
        // ====================================================================
        test_num = 6;
        $display("\n--- TEST %0d: Cache Coherence Test (Core1 reads Core0's data) ---", test_num);
        core1_read(32'h0000_1000);
        check_data(32'hDEADBEEF, cpu1_rdata, 1);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 7: Both cores read same location (Shared state)
        // ====================================================================
        test_num = 7;
        $display("\n--- TEST %0d: Both cores read same location ---", test_num);
        core0_read(32'h0000_3000);
        repeat(5) @(posedge clk);
        core1_read(32'h0000_3000);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 8: Core0 writes to shared location (S->M, invalidate Core1)
        // ====================================================================
        test_num = 8;
        $display("\n--- TEST %0d: Core0 writes to shared location (S->M) ---", test_num);
        core0_write(32'h0000_3000, 32'h12345678);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 9: Core1 reads updated value
        // ====================================================================
        test_num = 9;
        $display("\n--- TEST %0d: Core1 reads updated value ---", test_num);
        core1_read(32'h0000_3000);
        check_data(32'h12345678, cpu1_rdata, 1);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 10: Multiple writes to same location
        // ====================================================================
        test_num = 10;
        $display("\n--- TEST %0d: Multiple consecutive writes ---", test_num);
        core0_write(32'h0000_4000, 32'hAAAAAAAA);
        repeat(3) @(posedge clk);
        core0_write(32'h0000_4000, 32'hBBBBBBBB);
        repeat(3) @(posedge clk);
        core0_read(32'h0000_4000);
        check_data(32'hBBBBBBBB, cpu0_rdata, 0);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 11: Different cache lines - no interference
        // ====================================================================
        test_num = 11;
        $display("\n--- TEST %0d: Different cache lines ---", test_num);
        core0_write(32'h0000_5000, 32'h11111111);
        repeat(3) @(posedge clk);
        core1_write(32'h0000_6000, 32'h22222222);
        repeat(5) @(posedge clk);
        core0_read(32'h0000_5000);
        check_data(32'h11111111, cpu0_rdata, 0);
        repeat(3) @(posedge clk);
        core1_read(32'h0000_6000);
        check_data(32'h22222222, cpu1_rdata, 1);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 12: Bus arbitration test (Core 0 priority)
        // ====================================================================
        test_num = 12;
        $display("\n--- TEST %0d: Bus arbitration (simultaneous requests) ---", test_num);
        // Both cores request at same time - Core0 should get priority
        fork
            core0_read(32'h0000_7000);
            core1_read(32'h0000_8000);
        join
        repeat(10) @(posedge clk);
        
        // ====================================================================
        // TEST 13: Read-Modify-Write sequence
        // ====================================================================
        test_num = 13;
        $display("\n--- TEST %0d: Read-Modify-Write sequence ---", test_num);
        core0_read(32'h0000_9000);
        repeat(3) @(posedge clk);
        core0_write(32'h0000_9000, cpu0_rdata + 32'h100);
        repeat(3) @(posedge clk);
        core0_read(32'h0000_9000);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 14: Cache line replacement scenario
        // ====================================================================
        test_num = 14;
        $display("\n--- TEST %0d: Same index different tag (conflict) ---", test_num);
        core0_write(32'h0000_A000, 32'hAAAA0000);  // Index 0x200
        repeat(5) @(posedge clk);
        core0_write(32'h0010_A000, 32'hBBBB0000);  // Same index, different tag
        repeat(5) @(posedge clk);
        core0_read(32'h0010_A000);
        check_data(32'hBBBB0000, cpu0_rdata, 0);
        repeat(5) @(posedge clk);
        
        // ====================================================================
        // TEST 15: Stress test - alternating cores
        // ====================================================================
        test_num = 15;
        $display("\n--- TEST %0d: Alternating core accesses ---", test_num);
        core0_write(32'h0000_B000, 32'h1111);
        repeat(3) @(posedge clk);
        core1_write(32'h0000_B000, 32'h2222);
        repeat(3) @(posedge clk);
        core0_write(32'h0000_B000, 32'h3333);
        repeat(3) @(posedge clk);
        core1_read(32'h0000_B000);
        check_data(32'h3333, cpu1_rdata, 1);
        repeat(5) @(posedge clk);
        
        // Final summary
        repeat(10) @(posedge clk);
        $display("\n========================================");
        $display("       Test Summary                     ");
        $display("========================================");
        $display("Total Tests: %0d", test_num);
        $display("Total Errors: %0d", errors);
        if (errors == 0) begin
            $display("*** ALL TESTS PASSED ***");
        end else begin
            $display("*** SOME TESTS FAILED ***");
        end
        $display("========================================\n");
        
        $finish;
    end
    
    // Timeout watchdog
    initial begin
        #100000;
        $display("\nERROR: Simulation timeout!");
        $finish;
    end
    
    // Waveform dump
    initial begin
        $dumpfile("mesi_tb.vcd");
        $dumpvars(0, mesi_tb);
    end

endmodule
