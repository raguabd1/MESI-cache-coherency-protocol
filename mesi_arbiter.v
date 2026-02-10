

module bus_arbiter (
    input clk,
    input rst_n,
    input req0, //// From Cache Core 0: High when Core 0 needs the bus 
                             // (e.g., for a Refill or Write-back).
    input req1, //// From Cache Core 1: High when Core 1 needs the bus.
    output reg grant0, // To Cache Core 0: Grants permission to drive 
                             // address/command signals onto the bus.
    output reg grant1 // To Cache Core 1: Grants permission to drive 
                             // address/command signals onto the bus.
);
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            grant0 <= 1'b0;
            grant1 <= 1'b0;
        end else begin
            grant0 <= req0;    //first request is given high priority.
            grant1 <= req1 && !req0;
        end
    end
endmodule
