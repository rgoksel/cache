`timescale 1ns/100fs

`define numAddr 6
`define numWords 64
//`define wordLength 128

module TopSRAM_tag (
    input wire CE,               // Chip Enable
    input wire WEB,              // Write Enable Bar (active low)
    input wire OEB,              // Output Enable Bar (active low)
    input wire CSB,              // Chip Select Bar (active low)
    input wire [(`numAddr-1):0] A, // Address input
    input wire [`wordLength-1:0] I, // Data input
    output wire [`wordLength-1:0] O  // Combined Data output from 4 SRAMs
);

    // Output signals from each SRAM module
    wire [`wordLength-1:0] O1, O2;

	assign	CSB_RAM0	= CSB == 0 ? 1 : 0;
	assign	CSB_RAM1	= CSB == 1 ? 1 : 0;


	
    // Instantiate 2 SRAM1RW64x128 modules
    SRAM2RW64x32 SRAM0 (
        .A(A),
        .CE(CE),
        .WEB(!WEB),
        .OEB(!OEB),
        .CSB(!CSB_RAM0),
        .I(I),
        .O(O1)
    );

    SRAM2RW64x32 SRAM1 (
        .A(A),
        .CE(CE),
        .WEB(!WEB),
        .OEB(!OEB),
        .CSB(!CSB_RAM0),
        .I(I),
        .O(O2)
    );

  
	assign O = (CSB == 0) ? O1 :
	           (CSB == 1) ? O2 : `wordLength'd0;
endmodule
