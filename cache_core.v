
//This is the "Brain" where everything we've discussed so far 
//comes together. The cache_core_updated module integrates the storage, 
//the MESI logic, and the bus handshaking into a single functional unit.

module cache_core_updated (
    input clk,
    input rst_n,
    // CPU Interface
    input [31:0] cpu_addr,
    input [31:0] cpu_wdata,
    input [1:0] cpu_op,
    output [31:0] cpu_rdata,
    output reg cpu_ready,
    // Bus Interface - Input (snooping)
    input [31:0] bus_addr_in,
    input [1:0] bus_cmd_in,
    input [31:0] bus_data_in,
    // Bus Interface - Output (driving)
    output reg [31:0] bus_addr_out,
    output reg [1:0] bus_cmd_out,
    output [31:0] bus_data_out,
    output bus_data_drive,
    // Control
    input bus_grant,
    input mem_ready
);

    // Internal state
    reg [1:0] current_state, next_state;
    reg [19:0] current_tag;
    wire [19:0] tag_out;
    wire [1:0] state_out;
    wire [31:0] data_out;
    
    // Control signals
    reg data_we;
    reg tag_we;
    reg [31:0] data_wdata;
    
    
    //Snooping (Highest Priority): If snoop_hit is detected (meaning another CPU is 
    //touching our data), the cache immediately updates its local tag_store
    // with the snoop_next_state. If we have the data in the Modified state, 
    //we assert bus_data_drive to put our "dirty" data onto the bus for the other
    // requester.
    
    // Hit and miss detection
    wire hit = (cpu_addr[31:12] == tag_out) && (state_out != 2'b00);
    wire miss = (cpu_op != 2'b00) && !hit;
    
    // Memory request control
    wire mem_req_ctrl;
    
    //Cache Hit: If the CPU requests data and we have it, cpu_ready goes high immediately.
    //On Read: Data is provided from the data_store.
    //On Write: The data is updated, and the FSM determines if we need to tell 
    //the bus (e.g., transitioning from Shared to Modified).
    //Cache Miss (Lowest Priority): If we don't have the data,
    // we must wait for bus_grant. Once granted, the refill_ctrl initiates a
    //memory request. When mem_ready arrives, the cache is updated, and the CPU
    // is finally told it can proceed via cpu_ready.
    // FSM signals
    
    wire [1:0] fsm_next_state;
    wire [1:0] fsm_bus_req;
    wire bus_shared = 1'b0;  // Simplified: assume not shared for now
    
    // Snooper signals
    wire [1:0] snoop_next_state;
    wire snoop_hit;
    
    // Drive bus data when snooping and we have Modified data
    assign bus_data_drive = snoop_hit && (state_out == 2'b11);
    assign bus_data_out = data_out;
    
    // Cache Refill/Write-back Controller
    cache_refill_write_back_ctrl refill_ctrl (
        .clk(clk),
        .rst_n(rst_n),
        .miss(miss && bus_grant),
        .mem_ready(mem_ready),
        .mem_req(mem_req_ctrl)
    );
    
    // MESI FSM Controller
    mesi_fsm_controller fsm (
        .cpu_req(cpu_op),
        .current_state(state_out),
        .bus_shared_i(bus_shared),
        .next_state(fsm_next_state),
        .bus_req_type(fsm_bus_req)
    );
    
    // Snooper
    mesi_snooper snooper (
        .bus_addr(bus_addr_in),
        .bus_cmd(bus_cmd_in),
        .local_tag(tag_out),
        .local_state(state_out),
        .snoop_nxt_state(snoop_next_state),
        .snoop_hit_o(snoop_hit)
    );
    
    // Data Array
    cache_data_array data_store (
        .clk(clk),
        .index(cpu_addr[11:2]),
        .wdata(data_wdata),
        .we(data_we),
        .rdata(data_out)
    );
    
    // Tag Array
    mesi_tag_array tag_store (
        .clk(clk),
        .rst_n(rst_n),
        .index(cpu_addr[11:2]),
        .tag_in(cpu_addr[31:12]),
        .state_in(next_state),
        .write_en(tag_we),
        .tag_out(tag_out),
        .state_out(state_out)
    );
    
    // CPU read data
    assign cpu_rdata = data_out;
    
    // Main control logic
    always @(*) begin
        // Default values to avoid latches
        next_state = state_out;
        data_we = 1'b0;
        tag_we = 1'b0;
        data_wdata = 32'h0;
        cpu_ready = 1'b0;
        bus_addr_out = 32'h0;
        bus_cmd_out = 2'b00;
        
        // Snooping takes priority
        if (snoop_hit && !bus_grant) begin
            next_state = snoop_next_state;
            tag_we = 1'b1;
            cpu_ready = (cpu_op == 2'b00);
        end
        // Hit case
        else if (hit) begin
            cpu_ready = 1'b1;
            if (cpu_op == 2'b10) begin  // Write
                data_we = 1'b1;
                data_wdata = cpu_wdata;
                next_state = fsm_next_state;
                tag_we = 1'b1;
                bus_addr_out = cpu_addr;
                bus_cmd_out = fsm_bus_req;
            end
        end
        // Miss case with grant
        else if (miss && bus_grant) begin
            bus_addr_out = cpu_addr;
            bus_cmd_out = fsm_bus_req;
            
            if (mem_ready) begin
                // Refill from memory
                data_we = 1'b1;
                data_wdata = bus_data_in;
                next_state = fsm_next_state;
                tag_we = 1'b1;
                cpu_ready = 1'b1;
            end
        end
        // No operation
        else if (cpu_op == 2'b00) begin
            cpu_ready = 1'b1;
        end
    end

endmodule


