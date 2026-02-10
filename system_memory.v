module simple_memory (
    input clk,
    input rst_n,
    input mem_req,
    input [31:0] mem_addr,
    input [31:0] mem_wdata,
    input mem_we,
    output reg [31:0] mem_rdata,
    output reg mem_ready
);
    reg [31:0] mem [0:1023];
    reg [1:0] delay_counter;
    integer i;
    
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            mem[i] = 32'h0000_0000 + i;  // Initialize with simple pattern
        end
    end
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_ready <= 1'b0;
            delay_counter <= 2'b00;
            mem_rdata <= 32'h0;
        end else begin
            if (mem_req && !mem_ready) begin
                if (delay_counter == 2'b10) begin  // 3 cycle delay
                    mem_ready <= 1'b1;
                    if (mem_we) begin
                        mem[mem_addr[11:2]] <= mem_wdata;
                        mem_rdata <= mem_wdata;
                    end else begin
                        mem_rdata <= mem[mem_addr[11:2]];
                    end
                    delay_counter <= 2'b00;
                end else begin
                    delay_counter <= delay_counter + 1'b1;
                end
            end else begin
                mem_ready <= 1'b0;
                delay_counter <= 2'b00;
            end
        end
    end
endmodule
