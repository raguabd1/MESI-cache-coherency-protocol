


module mesi_top (
    input clk,
    input rst_n,
    // Core 0 CPU Interface
    input [31:0] cpu0_addr,
    input [31:0] cpu0_wdata,
    input [1:0] cpu0_op,      // 00=NOP, 01=RD, 10=WR
    output [31:0] cpu0_rdata,
    output cpu0_ready,
    // Core 1 CPU Interface
    input [31:0] cpu1_addr,
    input [31:0] cpu1_wdata,
    input [1:0] cpu1_op,
    output [31:0] cpu1_rdata,
    output cpu1_ready
);

    // Bus signals
    wire [31:0] bus_addr;
    wire [1:0] bus_cmd;
    wire [31:0] bus_data_wire;
    wire bus_data_driven;
    
    // Arbitration signals
    wire req0, req1;
    wire grant0, grant1;
    
    // Memory interface
    wire mem_req;
    wire mem_ready;
    wire [31:0] mem_data;
    
    // Core 0 outputs to bus
    wire [31:0] core0_bus_addr;
    wire [1:0] core0_bus_cmd;
    wire [31:0] core0_bus_data_out;
    wire core0_drives_data;
    
    // Core 1 outputs to bus
    wire [31:0] core1_bus_addr;
    wire [1:0] core1_bus_cmd;
    wire [31:0] core1_bus_data_out;
    wire core1_drives_data;
    
    // Bus multiplexing - grant0 has priority
    assign bus_addr = grant0 ? core0_bus_addr : (grant1 ? core1_bus_addr : 32'h0);
    assign bus_cmd = grant0 ? core0_bus_cmd : (grant1 ? core1_bus_cmd : 2'b00);
    
    // Bus data handling - memory or core can drive
    assign bus_data_driven = core0_drives_data | core1_drives_data | mem_ready;
    assign bus_data_wire = core0_drives_data ? core0_bus_data_out :
                          (core1_drives_data ? core1_bus_data_out :
                          (mem_ready ? mem_data : 32'h0));
    
    // Request signals from cores
    assign req0 = (cpu0_op != 2'b00) && !cpu0_ready;
    assign req1 = (cpu1_op != 2'b00) && !cpu1_ready;
    
    // Memory request - from whichever core has the grant
    assign mem_req = (grant0 && (cpu0_op != 2'b00)) || (grant1 && (cpu1_op != 2'b00));
    
    // Bus Arbiter
    bus_arbiter arbiter (
        .clk(clk),
        .rst_n(rst_n),
        .req0(req0),
        .req1(req1),
        .grant0(grant0),
        .grant1(grant1)
    );
    
    // Cache Core 0
    cache_core_updated core0 (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu0_addr),
        .cpu_wdata(cpu0_wdata),
        .cpu_op(cpu0_op),
        .cpu_rdata(cpu0_rdata),
        .cpu_ready(cpu0_ready),
        .bus_addr_in(bus_addr),
        .bus_cmd_in(bus_cmd),
        .bus_data_in(bus_data_wire),
        .bus_addr_out(core0_bus_addr),
        .bus_cmd_out(core0_bus_cmd),
        .bus_data_out(core0_bus_data_out),
        .bus_data_drive(core0_drives_data),
        .bus_grant(grant0),
        .mem_ready(mem_ready)
    );
    
    // Cache Core 1
    cache_core_updated core1 (
        .clk(clk),
        .rst_n(rst_n),
        .cpu_addr(cpu1_addr),
        .cpu_wdata(cpu1_wdata),
        .cpu_op(cpu1_op),
        .cpu_rdata(cpu1_rdata),
        .cpu_ready(cpu1_ready),
        .bus_addr_in(bus_addr),
        .bus_cmd_in(bus_cmd),
        .bus_data_in(bus_data_wire),
        .bus_addr_out(core1_bus_addr),
        .bus_cmd_out(core1_bus_cmd),
        .bus_data_out(core1_bus_data_out),
        .bus_data_drive(core1_drives_data),
        .bus_grant(grant1),
        .mem_ready(mem_ready)
    );
    
    // Simple Memory Model
    simple_memory memory (
        .clk(clk),
        .rst_n(rst_n),
        .mem_req(mem_req),
        .mem_addr(bus_addr),
        .mem_wdata(bus_data_wire),
        .mem_we(bus_cmd == 2'b10),
        .mem_rdata(mem_data),
        .mem_ready(mem_ready)
    );

endmodule
