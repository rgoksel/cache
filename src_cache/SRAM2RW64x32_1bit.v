module SRAM2RW64x32_1bit (CE1_i, CE2_i, WEB1_i, WEB2_i,  A1_i, A2_i, OEB1_i, OEB2_i, CSB1_i, CSB2_i, I1_i, I2_i, O1_i, O2_i);

input 	CSB1_i, CSB2_i;
input 	OEB1_i, OEB2_i;
input 	CE1_i, CE2_i;
input 	WEB1_i, WEB2_i;

input 	[`numAddr-1:0] 	A1_i, A2_i;
input 	[0:0] I1_i, I2_i;

output 	[0:0] O1_i, O2_i;

reg 	[0:0] O1_i, O2_i;
reg    	[0:0]  	memory[`numWords-1:0];
reg  	[0:0]	data_out1, data_out2;


and u1 (RE1, ~CSB1_i,  WEB1_i);
and u2 (WE1, ~CSB1_i, ~WEB1_i);
and u3 (RE2, ~CSB2_i,  WEB2_i);
and u4 (WE2, ~CSB2_i, ~WEB2_i);

//Primary ports

always @ (posedge CE1_i) 
	if (RE1)
		data_out1 = memory[A1_i];
always @ (posedge CE1_i) 
	if (WE1)
		memory[A1_i] = I1_i;
		

always @ (data_out1 or OEB1_i)
	if (!OEB1_i) 
		O1_i = data_out1;
	else
		O1_i =  1'bz;

//Dual ports	
always @ (posedge CE2_i)
  	if (RE2)
		data_out2 = memory[A2_i];
always @ (posedge CE2_i)
	if (WE2)
		memory[A2_i] = I2_i;
		
always @ (data_out2 or OEB2_i)
	if (!OEB2_i) 
		O2_i = data_out2;
	else
		O2_i = 1'bz;

endmodule