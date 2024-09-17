`timescale 1ns / 1ps


module deneme_mem #(
    parameter MEM_DEPTH = 256
)(
    input  clk_i,
    input  rst_ni,
    // Memory interface between the core and memory
    input  req,
    output reg gnt,
    input  we,
    input  [31:0]  addr,
    input  [127:0] wdata,
    input  [15:0]  wstrb,
    output reg [127:0] rdata,
    output reg rvalid
);
    localparam ADDR_W = $clog2(MEM_DEPTH);
    reg [127:0] memory [MEM_DEPTH-1:0];
    integer i;
    
    initial begin
        for (i = 0; i < MEM_DEPTH; i = i + 1) begin
            memory[i] = {$random, $random, $random, $random};
        end
    end
    
    always @(posedge clk_i) begin
        if(req && we) begin
            for(i=0; i<16; i=i+1) begin
                if(wstrb[i])
                    memory[addr[4+:ADDR_W]][i*8+:8] <= wdata[i*8 +: 8];
            end
        end else if(req && ~we) begin
            rdata <= memory[addr[4+:ADDR_W]];
        end
    end
    
    always @(posedge clk_i or posedge rst_ni) begin
        if(rst_ni) begin
            rvalid <= 1'b0;
            gnt <= 1'b0;
        end else begin
            rvalid <= req && ~we && gnt;
            gnt <= req;
        end
    end

endmodule

