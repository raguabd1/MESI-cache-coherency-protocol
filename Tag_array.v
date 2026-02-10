
//Tag Array, a specialized memory structure used in caches to 
//track which memory addresses are currently stored and what 
//their status is according to the MESI (Modified, Exclusive, Shared, Invalid)
// protocol.
module mesi_tag_array (
    input clk,
    input rst_n,
    input [9:0] index,
    input [19:0] tag_in,
    input [1:0] state_in,
    input write_en,
    output [19:0] tag_out,
    output [1:0] state_out
);
//2-bits for storing the state, 20-bits for storing the address Tag.
    reg [21:0] storage [0:1023];
    integer i;
    
    initial begin
        for (i = 0; i < 1024; i = i + 1) begin
            storage[i] = 22'b0;
        end
    end
    
    always @(posedge clk) begin
        if (write_en) storage[index] <= {state_in, tag_in};
    end
    
    assign {state_out, tag_out} = storage[index];
endmodule

