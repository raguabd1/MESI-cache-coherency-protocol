//
//This module is the brain of your cache line.
// While the Tag and Data arrays handle storage, this FSM (Finite State Machine) controller 
//implements the actual MESI protocol logic for CPU-side requests. 
//It decides how the state of a cache line should change when the processor tries 
//to read or write to it.


//The controller is purely combinational. 
//It looks at the current_state (provided by your Tag Array) 
//and the cpu_req to determine the next_state and what needs to be 
//communicated to other caches via the bus (bus_req_type).

module mesi_fsm_controller (
    input [1:0] cpu_req,
    input [1:0] current_state,
    input bus_shared_i,
    output reg [1:0] next_state,
    output reg [1:0] bus_req_type
);
    localparam I = 2'b00, S = 2'b01, E = 2'b10, M = 2'b11;
    localparam NOP = 2'b00, RD = 2'b01, WR = 2'b10;
    
    always @(*) begin
        next_state = current_state;
        bus_req_type = NOP;
        
        case (current_state)
            I: if (cpu_req == RD) begin
                next_state = bus_shared_i ? S : E;
                bus_req_type = RD;
            end else if (cpu_req == WR) begin
                next_state = M;
                bus_req_type = WR;
            end
            
            S: if (cpu_req == WR) begin
                next_state = M;
                bus_req_type = WR;
            end
            
            E: if (cpu_req == WR) next_state = M;
            
            M: next_state = M;
            
            default: begin
                next_state = I;
                bus_req_type = NOP;
            end
        endcase
    end
endmodule
