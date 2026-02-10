
// This module acts as the intermediary between your fast cache 
//and the much slower main memory. In a MESI-based system,
// when a "miss" occurs (you need data you don't have, 
//or you need to write to a line you don't own), 
//this controller handles the handshake to fetch or update that data.

module cache_refill_write_back_ctrl (
    input clk,
    input rst_n,
    input miss, //When the cache controller detects a miss, it asserts the miss signal.
    input mem_ready,
    output reg mem_req
);

//As long as a miss is active and the memory hasn't finished its job 
//(!mem_ready), the controller holds mem_req high. 
//This tells the memory controller: "I need you to perform a bus transaction."

//Once the main memory or the system bus responds that the data is ready 
//(or the write-back is done), mem_req is de-asserted on the next clock edge.

//Unlike the combinational FSM we looked at earlier, this is a registered output.
// This is crucial for physical timing; 
//it ensures that the mem_req signal is stable and synchronized to the clock 
//before it travels across the PCB or long internal bus wires.

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) 
            mem_req <= 1'b0;
        else if (miss && !mem_ready) 
            mem_req <= 1'b1;
        else 
            mem_req <= 1'b0;
    end
endmodule
