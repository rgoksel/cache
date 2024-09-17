`timescale 1ns/100fs

`define numAddr 6
`define numWords 64
`define wordLength 128

module TopSRAM (
    input wire CE,               // Chip Enable
    input wire WEB,              // Write Enable Bar (active low)
    input wire OEB,              // Output Enable Bar (active low)
    input wire [1:0] CSB,              // Chip Select Bar (active low)
    input wire [(`numAddr-1):0] A, // Address input
    input wire [`wordLength-1:0] I, // Data input
    output wire [`wordLength-1:0] O  // Combined Data output from 4 SRAMs
);

    // Output signals from each SRAM module
    wire [`wordLength-1:0] O1, O2, O3, O4;

    // CSB signals based on the selected bits of the address A
	assign	CSB_RAM0	= CSB == 2'b00 ? 1 : 0;
	assign	CSB_RAM1	= CSB == 2'b01 ? 1 : 0;
	assign	CSB_RAM2	= CSB == 2'b10 ? 1 : 0;
	assign	CSB_RAM3	= CSB == 2'b11 ? 1 : 0;
	
    // Instantiate 4 SRAM1RW64x128 modules
    SRAM1RW64x128 SRAM0 (
        .A(A),
        .CE(CE),
        .WEB(WEB),
        .OEB(OEB),
        .CSB(CSB_RAM0),
        .I(I),
        .O(O1)
    );

    SRAM1RW64x128 SRAM1 (
        .A(A),
        .CE(CE),
        .WEB(WEB),
        .OEB(OEB),
        .CSB(CSB_RAM1),
        .I(I),
        .O(O2)
    );

    SRAM1RW64x128 SRAM2 (
        .A(A),
        .CE(CE),
        .WEB(WEB),
        .OEB(OEB),
        .CSB(CSB_RAM2),
        .I(I),
        .O(O3)
    );

    SRAM1RW64x128 SRAM3 (
        .A(A),
        .CE(CE),
        .WEB(WEB),
        .OEB(OEB),
        .CSB(CSB_RAM3),
        .I(I),
        .O(O4)
    );
	
    // Output selection based on the selected bits of the address A
	assign O = (CSB == 2'b00) ? O1 :
	           (CSB == 2'b01) ? O2 :
	           (CSB == 2'b10) ? O3 :
	           (CSB == 2'b11) ? O4 :  `wordLength'd0;
	
endmodule
