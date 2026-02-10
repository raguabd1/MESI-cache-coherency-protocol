

module cache_data_array (
    input clk,
    input [9:0] index,
    input [31:0] wdata,
    input we,
    output [31:0] rdata
);
    reg [31:0] data_ram [0:1023];
    integer i;
    
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            data_ram[i] = 32'h0;
        end
    end
    
    always @(posedge clk) begin
        if (we) data_ram[index] <= wdata;
    end
    
    assign rdata = data_ram[index];
endmodule
