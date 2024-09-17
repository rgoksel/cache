module tb_mem_connect;

    // Parameters
    localparam USE_SRAM = 0;

    // Inputs
    reg clk;
    reg rst;
    reg core_wr_i;
    reg core_en_i;
    reg [31:0] core_addr_i;
    reg [31:0] core_data_i;
    reg core_data_en;
    reg core_instr_en;

    // Outputs
    wire [31:0] core_data_o;
    wire core_stall_o;
    integer i;

    // Instantiate the Unit Under Test (UUT)
    mem_connect #(USE_SRAM) uut (
        .clk(clk), 
        .rst(rst), 
        .core_wr_i(core_wr_i), 
        .core_en_i(core_en_i), 
        .core_addr_i(core_addr_i), 
        .core_data_i(core_data_i), 
        .core_data_o(core_data_o), 
        .core_stall_o(core_stall_o), 
        .core_data_en(core_data_en), 
        .core_instr_en(core_instr_en)
    );

    // Clock generation
    always begin
        #5 clk = ~clk; // 100 MHz clock
    end

    // Test sequence
    initial begin
        // Initialize Inputs
        clk = 0;
        rst = 0;
        core_wr_i = 0;
        core_en_i = 0;
        core_addr_i = 32'd0;
        core_data_i = 32'd0;
        core_data_en = 0;
        core_instr_en = 0;

        // Reset Sequence
        #10 rst = 1;

        // Test Case 1: Write to Memory
        #15;
        core_en_i = 1;
        core_wr_i = 1;
        core_addr_i = 32'h0000_0C30;
        core_data_i = 32'hCAFEBABE;
        core_data_en = 1;
        core_instr_en = 0;
        #40;

        // Test Case 2: Read from Memory (After Write)
        core_wr_i = 1;
        core_addr_i = 32'h0000_0C00;
        core_data_en = 1;
        core_data_i = 32'hABCDEFAB;

        #40;
        
        core_wr_i = 1;
        core_addr_i = 32'h00AB0001;
        core_data_i = 32'hBADC0DE;
        core_data_en = 1;

        #40;

        // Test Case 3: Instruction Fetch Attempt (Stall Check)
        core_en_i = 1;
        core_wr_i = 1;
        core_addr_i = 32'h00ABCD10;
        core_data_i = 32'hB00100DE;

        #40;
        core_en_i = 1;
        //core_instr_en = 1;
        core_addr_i = 32'h00CBA010;
        core_data_i = 32'hB01011CB;
        #40;
        core_en_i = 1;
        core_addr_i = 32'h0000_000B;
        core_data_i = 32'hBADC0DE;

        #40;
        
        core_en_i = 1;
        //core_instr_en = 1;
        core_addr_i = 32'h0001A1BC;

        #40;
        // Test Case 4: Switch from Instruction Fetch to Data Operation
        
        core_instr_en = 0;
        core_en_i = 1;
        core_wr_i = 1;
        core_addr_i = 32'hABCD00AB;
        core_data_en = 1;

        #40;

        // Test Case 5: Attempt Write to Read-Only Memory Area
        core_wr_i = 1;
        core_addr_i = 32'hFFFF_0000; // Assume this is a read-only region
        core_data_i = 32'hBADC0DE;

        #40;

        // Test Case 6: Multiple Sequential Writes
        core_addr_i = 32'h0000_0010;
        core_data_i = 32'h12345678;

        #40;
        core_addr_i = 32'h0000_0014;
        core_data_i = 32'h87654321;

        #70;
        core_addr_i = 32'h0000_0018;
        core_data_i = 32'hDEADBEEF;

        #70;

        // Test Case 7: Multiple Sequential Reads
        core_wr_i = 1;

        core_addr_i = 32'h0000_0010;
        #70;

        core_addr_i = 32'h0000_0014;
        #70;

        core_addr_i = 32'h0000_0018;
        #70;

        // Test Case 8: No Operation (Check for No Stall)
        core_en_i = 1;
        core_wr_i = 1;
        core_data_en = 1;
        core_instr_en = 0;

        #70;

        // Test Case 9: Random Access Pattern
        core_en_i = 1;
        core_wr_i = 1;
        core_addr_i = 32'h0000_0020;
        core_data_i = 32'hAAAAAAAA;

        #20;
        core_addr_i = 32'h0000_0030;
        core_data_i = 32'h55555555;

        #10;
        core_wr_i = 0;
        core_addr_i = 32'h0000_0020;

        #10;
        core_addr_i = 32'h0000_0030;

        #10;

        // Test Case 10: Continuous Write and Read in Loop
        repeat (5) begin
            core_wr_i = 1;
            core_addr_i = core_addr_i + 32'h0000_0010;
            core_data_i = core_data_i + 32'h0000_1111;
            #10;
            core_wr_i = 0;
            #10;
            core_wr_i = 1;
        end

        #10;

        // Test Case 11: Access Unaligned Addresses
        core_addr_i = 32'h0000_0003; // Unaligned address
        core_data_i = 32'hBADBADBAD;
        core_wr_i = 1;

        #10;

        core_wr_i = 0;
        core_addr_i = 32'h0000_0003;

        #10;

        // Test Case 12: Simultaneous Data and Instruction Enable
        core_data_en = 1;
        core_instr_en = 1;

        core_wr_i = 1;
        core_addr_i = 32'h0000_0040;
        core_data_i = 32'h11111111;

        #10;

        // Test Case 13: Rapid Enable/Disable of Core Interface
        core_en_i = 1;
        core_wr_i = 1;
        core_addr_i = 32'h0000_0050;
        core_data_i = 32'h22222222;

        #10;
        core_en_i = 0;
        #10;
        core_en_i = 1;

        #10;

        // Test Case 14: Boundary Address Access
        core_wr_i = 1;
        core_addr_i = 32'hFFFF_FFFC;
        core_data_i = 32'h33333333;

        #10;

        core_wr_i = 0;
        core_addr_i = 32'hFFFF_FFFC;

        #10;

        // Test Case 15: Idle State and Monitor Core Stall
        core_en_i = 0;
        core_data_en = 0;
        core_instr_en = 0;
        #10;

        // Test Case 16: Attempt Access to Invalid Address Range
        core_en_i = 1;
        core_addr_i = 32'hABCD_EF00;
        core_wr_i = 1;
        core_data_i = 32'h44444444;

        #10;

        core_wr_i = 0;
        core_addr_i = 32'hABCD_EF00;

        #10;

        // Test Case 17: Alternating Between Different Memory Regions
        core_wr_i = 1;
        core_addr_i = 32'h0000_0060;
        core_data_i = 32'h55555555;

        #10;
        core_addr_i = 32'hFFFF_0010;
        core_data_i = 32'h66666666;

        #10;
        core_addr_i = 32'h0000_0070;
        core_data_i = 32'h77777777;

        #10;
        core_addr_i = 32'hFFFF_0020;
        core_data_i = 32'h88888888;

        #10;

        // Test Case 18: Simulate Burst Write Operation
        core_wr_i = 1;
        core_en_i = 1;
        core_data_en = 1;
        for (i = 0; i < 8; i = i + 1) begin
            core_addr_i = core_addr_i + 32'h0000_0010;
            core_data_i = core_data_i + 32'h0000_0101;
            #10;
        end

        #10;

        // Test Case 19: Simulate Cache Miss Scenario
        core_wr_i = 0;
        core_en_i = 1;
        core_data_en = 1;
        core_addr_i = 32'h0000_0080;
        #10;

        // Test Case 20: Power-On and Reset Recovery
        core_en_i = 0;
        core_data_en = 0;
        core_instr_en = 0;
        rst = 0;
        #10;
        rst = 1;
        #10;

        core_en_i = 1;
        core_wr_i = 1;
        core_addr_i = 32'h0000_0090;
        core_data_i = 32'h99999999;

        #10;

        // End of Test
        core_en_i = 0;
        core_data_en = 0;
        core_instr_en = 0;


        #10 $stop;
    end

endmodule
