`timescale 1ns / 1ps

module mem_connect (
    input clk,
    input rst,
    input             core_wr_i,
    input             core_en_i, 
    input [31:0]      core_addr_i,
    input [31:0]      core_data_i,

    output [31:0] core_data_o,
    output       core_stall_o,
    input core_data_en,  // if this is high then data cache gonna work
    input core_instr_en
);

    wire gnt_i; // gnt 1 olunca req_o istegibi kabul edildigini anliyoruz
    wire rvalid_i; // okunan veri gecerli ve sana veriyorum demek  

    wire req_o; //read or write operation'a baslamak istiyoruz sinyali 
    wire ram_we_o; //mem'e birsey yazilacagı zaman aktif olur
    
    wire [31:0] ram_addr_o; //ramden nerden okicaz
    wire [127:0]  ram_wr_data_o; //ram'e yazilacak data
    wire  [127:0]  ram_rd_data_i; //ramdan_okunan data
    wire [15:0] ram_wr_strb_o;

    deneme_mem #(.MEM_DEPTH(16))
    deneme_mem(
        .clk_i  (clk),
        .rst_ni (~rst),
        .req    (req_o),
        .gnt    (gnt_i   ),
        .we     (ram_we_o    ),
        .addr   (ram_addr_o  ),
        .wdata  (ram_wr_data_o ),
        .wstrb  (ram_wr_strb_o ),
        .rdata  (ram_rd_data_i ),
        .rvalid (rvalid_i)
    );
    
    cache_top_1 cahce_deneme_1 (
        .clk_i(clk), .rst_ni(rst), .core_wr_i(core_wr_i), .core_en_i(core_en_i), .core_addr_i(core_addr_i), .core_data_i(core_data_i),
        .core_data_o(core_data_o), .core_stall_o(core_stall_o), .core_data_en(core_data_en), .core_instr_en(core_instr_en),
        .gnt_i(gnt_i), .rvalid_i(rvalid_i), .req_o(req_o), .ram_we_o(ram_we_o), 
        .ram_addr_o(ram_addr_o), .ram_wr_data_o(ram_wr_data_o), .ram_rd_data_i(ram_rd_data_i), .ram_wr_strb_o(ram_wr_strb_o)
    );
    
    
    endmodule
