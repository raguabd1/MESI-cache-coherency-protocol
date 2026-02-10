

//The MESI Snooper is the "security guard" of your cache line.
// Its job is to watch the system bus and see if other processors 
//are trying to read or write to a memory address that you also have a copy of.
// If they are, the snooper tells your local cache controller how to downgrade its 
//state to maintain consistency.
module mesi_snooper (
    input [31:0] bus_addr,
    input [1:0] bus_cmd,
    input [19:0] local_tag,
    input [1:0] local_state,
    output reg [1:0] snoop_nxt_state,
    output reg snoop_hit_o
);
//A "snoop hit" only occurs if the address on the bus matches your 
//local_tag and your local state isn't already Invalid (2'b00).

    wire match = (bus_addr[31:12] == local_tag) && (local_state != 2'b00);
    
    always @(*) begin
        snoop_nxt_state = local_state;
        snoop_hit_o = match;
        
        if (match) begin
            case (bus_cmd)
                2'b01: snoop_nxt_state = 2'b01;  // Bus Read -> Shared
                2'b10: snoop_nxt_state = 2'b00;  // Bus Write -> Invalid
                default: snoop_nxt_state = local_state;
            endcase
        end
    end
endmodule
