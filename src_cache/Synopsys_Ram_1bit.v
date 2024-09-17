`timescale 1ns/100fs

`define numAddr 6
`define numWords 64
`define wordLength 128

module SRAM1RW64x128_1bit (CE_i, WEB_i,  A_i, OEB_i, CSB_i, I_i, O_i);

input CSB_i;
input OEB_i;
input CE_i;
input WEB_i;

input 	[`numAddr-1:0] 	A_i;
input 	[0:0] I_i;

output 	[0:0] O_i;

reg 	[0:0]O_i;
reg    	[0:0]  	memory[`numWords-1:0];
reg  	[0:0]	data_out;


// Write Mode
and u1 (RE, ~CSB_i,  WEB_i);
and u2 (WE, ~CSB_i, ~WEB_i);


always @ (posedge CE_i)  begin
	if (RE)
		data_out = memory[A_i];
end

always @ (posedge CE_i) begin
	if (WE)
		memory[A_i] = I_i;
end
	
		

always @ (data_out or OEB_i) begin
	if (!OEB_i) 
		O_i = data_out;
	else
		O_i =  1'bz;
end


endmodule