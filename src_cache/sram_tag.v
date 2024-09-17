`timescale 1ns / 1ps

module sram_tag #(
  parameter WORD_SIZE = 128,
  parameter ADDR_WIDTH = 6 
) (
  input                      clk_i,
  input                      wr_i,
  input                      en_i,
  input [ADDR_WIDTH-1:0]     addr_i,
  input [WORD_SIZE-1:0]      data_i,
  output reg [WORD_SIZE-1:0] data_o
);

  reg [WORD_SIZE-1:0] RAM [2**ADDR_WIDTH-1:0];

/*  initial begin
    for (integer idx = 0; idx < 2**ADDR_WIDTH-1; idx = idx + 1)
      $dumpvars(0, RAM[idx]);
  end*/

  always @(posedge clk_i) begin
    if (en_i) begin
      if (wr_i) begin
        RAM[addr_i] <= data_i;
        end
 
      data_o <= RAM[addr_i];
    end
  end
endmodule
