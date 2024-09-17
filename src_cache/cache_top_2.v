`timescale 1ns / 1ps

module cache_top_1(
    // Core
    input             clk_i,
    input             rst_ni,
    input             core_wr_i,
    input             core_en_i, 
    input [31:0]      core_addr_i,
    input [31:0]      core_data_i,

    output reg [31:0] core_data_o,
    output reg        core_stall_o,
    input core_data_en,  // if this is high then data cache gonna work
    input core_instr_en, //that means instruction cache gonna work
    
    // RAM
    input gnt_i, // gnt 1 olunca req_o istegibi kabul edildigini anliyoruz
    input rvalid_i, // okunan veri gecerli ve sana veriyorum demek  

    output reg req_o, //read or write operation'a baslamak istiyoruz sinyali 
    output reg ram_we_o, //mem'e birsey yazilacagý zaman aktif olur
    
    output reg [31:0] ram_addr_o, //ramden nerden okicaz
    output reg [127:0]  ram_wr_data_o, //ram'e yazilacak data
    input      [127:0]   ram_rd_data_i, //ramdan_okunan data
    output reg [15:0] ram_wr_strb_o
    
 );

  reg          sram_en_i; //sram 1 olunca ?zerinde i?lem yapmaya 
  reg          write_permission;
  wire         gnt_and_rvalid;
  assign       gnt_and_rvalid = (gnt_i && rvalid_i);

// Neologisms 
  reg [127:0]  cache_data_1_i;
  wire [127:0] cache_data_1_o;

  wire [23:0]   cache_metadata_1_i;
  reg [1:0] cache_metadata_1_i_lru_field;
  reg [21:0]  cache_metadata_1_i_tag_field;

  assign cache_metadata_1_i = {cache_metadata_1_i_lru_field, cache_metadata_1_i_tag_field}; 

  wire [23:0] cache_metadata_1_o;
  wire [1:0]  cache_metadata_1_o_lru_field;
  wire [21:0] cache_metadata_1_o_tag_field;

  assign  cache_metadata_1_o_lru_field = cache_metadata_1_o[23:22];
  assign  cache_metadata_1_o_tag_field = cache_metadata_1_o[21:0];

  reg [127:0]  cache_data_2_i;
  wire [127:0] cache_data_2_o;

  wire [23:0]   cache_metadata_2_i;
  reg [1:0] cache_metadata_2_i_lru_field;
  reg [21:0]  cache_metadata_2_i_tag_field;

  assign cache_metadata_2_i = {cache_metadata_2_i_lru_field, cache_metadata_2_i_tag_field};

  wire [23:0] cache_metadata_2_o;
  wire [1:0]  cache_metadata_2_o_lru_field;
  wire [21:0] cache_metadata_2_o_tag_field;

  assign  cache_metadata_2_o_lru_field = cache_metadata_2_o[23:22];
  assign  cache_metadata_2_o_tag_field = cache_metadata_2_o[21:0];

  wire [21:0] tag_field = core_addr_i[31:10];
  wire [5:0]  set_number_field = core_addr_i[9:4]; //64 olcak data-instr i?in sat?r
  wire [1:0]  word_offset_field = core_addr_i[3:2];
  wire [1:0]  byte_offset_field = core_addr_i[1:0];
  
  wire [6:0] index_instr = {1'b0, set_number_field}; //burda 7 bite ??kard?m daatalar?nki 64-127 aras?nda oldu?u i?in
  
  wire [6:0] num64 = 7'b1000000; 
  wire [6:0] index_data = {num64[6], set_number_field[5:0]};
  
  wire [6:0] index;
  
  assign index = (core_data_en == 1 && core_instr_en == 0 ) ? index_data : index_instr; 

  sram #(
   .WORD_SIZE(128),
   .ADDR_WIDTH(7)
  ) CACHE_MEMORY_1 (
    .clk_i  (clk_i),
    .wr_i   (write_permission),
    .en_i   (sram_en_i),
    .addr_i (index),
    .data_i (cache_data_1_i),
    .data_o (cache_data_1_o)
  );

  sram #(
   .WORD_SIZE(128),
   .ADDR_WIDTH(7)
  ) CACHE_MEMORY_2 (
    .clk_i  (clk_i),
    .wr_i   (write_permission),
    .en_i   (sram_en_i),
    .addr_i (index),
    .data_i (cache_data_2_i),
    .data_o (cache_data_2_o)
  );

  sram #(
   .WORD_SIZE(24), //2/*lru counter*/+22/*tag*/
   .ADDR_WIDTH(7)
  ) METADATA_MEMORY_1 (
    .clk_i  (clk_i),
    .wr_i   (1'b1),
    .en_i   (sram_en_i),
    .addr_i (index),
    .data_i (cache_metadata_1_i),
    .data_o (cache_metadata_1_o)
  );

  sram #(
   .WORD_SIZE(24),
   .ADDR_WIDTH(7)
  ) METADATA_MEMORY_2 (
    .clk_i  (clk_i),
    .wr_i   (1'b1),
    .en_i   (sram_en_i),
    .addr_i (index),
    .data_i (cache_metadata_2_i),
    .data_o (cache_metadata_2_o)
  );
  
  reg [127:0] dirty_bit_1;
  reg [127:0] dirty_bit_2;
  reg [127:0] valid_bit_1;
  reg [127:0] valid_bit_2;

  reg [2:0] state;
   
  localparam [2:0] IDLE = 3'b000,
                   WRITE_CACHE = 3'b001,
                   READ_CACHE = 3'b010, 
                   UPDATE_MEM = 3'b011,
                   WAIT_MEM = 3'b100,
                   UPDATE_CACHE = 3'b101;
  
  localparam WRITE = 1'b1;
  localparam READ = 1'b0;
  
    wire present_in_1;
    wire present_in_2;
      
    assign present_in_1 = ((cache_metadata_1_o_tag_field == tag_field) && (valid_bit_1[index])) ? 1'b1: 0;
    assign present_in_2 = ((cache_metadata_2_o_tag_field == tag_field) && (valid_bit_2[index])) ? 1'b1: 0;
    
    
  
  
  
                      
  wire hit = present_in_1 || present_in_2;
  reg [1:0] prev_state;
  
  
    wire req_d;
    wire sram_en_i_d;
    wire core_stall_o_d;
    wire ram_we_o_d;
    wire write_permission_d;
    wire write_permission_tag_d;
    wire [127:0] valid_bit_1_d;
    wire [127:0] valid_bit_2_d;    
    wire [1:0] cache_metadata_1_i_lru_field_d;
    wire [1:0] cache_metadata_2_i_lru_field_d;
    wire [21:0] cache_metadata_1_i_tag_field_d;
    wire [21:0] cache_metadata_2_i_tag_field_d;
    wire [1:0] prev_state_d;
    
    
    wire [2:0] state_d;

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            state <= 3'd0;
        end
        else begin
            state <= state_d;
        end
    end 

    assign state_d = ((state == IDLE) && (core_en_i) && (core_wr_i == READ)) ? READ_CACHE:
                     ((state == IDLE) && (core_en_i) && (core_wr_i == WRITE)) ? WRITE_CACHE:
                     ((state == IDLE) && (core_en_i == 0)) ? IDLE:
                     ((state == READ_CACHE) && (present_in_1 == 1)) ? IDLE:
                     ((state == READ_CACHE) && (present_in_2 == 1)) ? IDLE:
                     ((state == READ_CACHE) && (present_in_1 == 0 && dirty_bit_1[index] == 0)) ? WAIT_MEM:
                     ((state == READ_CACHE) && (present_in_2 == 0 && dirty_bit_2[index] == 0)) ? WAIT_MEM:
                     ((state == READ_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 1) || (present_in_2 == 0 && dirty_bit_2[index] == 1))) ? UPDATE_MEM:
                     ((state == WRITE_CACHE) && (present_in_1 == 1 && dirty_bit_1[index] == 0)) ? IDLE:
                     ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_2[index] == 0)) ? IDLE:
                     ((state == WRITE_CACHE) && (present_in_1 == 0 && dirty_bit_1[index] == 0)) ? WAIT_MEM:
                     ((state == WRITE_CACHE) && (present_in_2 == 0 && dirty_bit_2[index] == 0)) ? WAIT_MEM:
                     ((state == WRITE_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 1) || (present_in_2 == 0 && dirty_bit_2[index] == 1))) ? UPDATE_MEM:
                     ((state == UPDATE_MEM) && (gnt_i && rvalid_i == 0)) ? WAIT_MEM :
                     ((state == UPDATE_MEM) && ((gnt_i && rvalid_i == 0) == 0)) ? WAIT_MEM :
                     ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && present_in_1 == 1)) ? IDLE:
                     ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && present_in_2 == 1)) ? IDLE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1)) ? UPDATE_CACHE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0)) ? UPDATE_CACHE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ? UPDATE_CACHE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ? UPDATE_CACHE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1)) ? IDLE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0)) ? IDLE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ? IDLE:
                     ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ? IDLE: state;
                     

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            req_o <= 0;
        end
        else begin
            req_o <= req_d;
        end
    end

    assign  req_d   =   ((state ==  READ_CACHE && ((present_in_1 == 0) && (present_in_2 == 0))) || (state ==  WRITE_CACHE && ((present_in_1 == 0) && (present_in_2 == 0))) || (state ==  UPDATE_MEM) ) ? 1'd1  :
                        ((state == IDLE) || (state ==  WAIT_MEM && gnt_and_rvalid == 1 && (prev_state == 2'b01 || prev_state == 2'b10))) ? 1'd0: req_o;
                        
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            sram_en_i <= 0;
        end
        else begin
            sram_en_i <= sram_en_i_d;
        end
    end

    assign sram_en_i_d = rst_ni ? 1'd1 : 1'd0;

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            core_stall_o <= 0;
        end
        else begin
            core_stall_o <= core_stall_o_d;

        end
    end

    assign core_stall_o_d = (((state ==  READ_CACHE) && ((present_in_1 == 0) && (present_in_2 == 0))) || 
                            ((state ==  WRITE_CACHE) && ((present_in_1 == 0) && (present_in_2 == 0)))) ? 1'd1  :
                            ((state ==  IDLE) || 
                            ((state == WAIT_MEM) && gnt_and_rvalid == 1 && prev_state == 2'b10)) ? 1'd0 : core_stall_o;
    
     always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            ram_we_o <= 0;
        end
        else begin
            ram_we_o <= ram_we_o_d;
        end
    end

    assign ram_we_o_d = (((state ==  READ_CACHE) && (present_in_1 == 0 && dirty_bit_1[index] == 1) && (present_in_2 == 0 && dirty_bit_2[index] == 1)) ||
                        ((state ==  WRITE_CACHE) && (present_in_1 == 0 && dirty_bit_1[index] == 1) && (present_in_2 == 0 && dirty_bit_2[index] == 1)) || (state ==  UPDATE_MEM)) ? 1'd1 :
                        ((state ==  IDLE) || ((state ==  READ_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 0) || (present_in_2 == 0 && dirty_bit_2[index] == 0))) ||
                        ((state ==  WRITE_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 0) || (present_in_2 == 0 && dirty_bit_2[index] == 0))) || (state ==  WAIT_MEM)) ? 1'd0 : ram_we_o_d;
 
  
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            write_permission <= 0;
        end
        else begin
            write_permission <= write_permission_d;
        end
    end
    
    assign write_permission_d = (((state == IDLE) && (core_wr_i == WRITE)) || 
                                ((state == READ_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 0) || (present_in_2 == 0 && dirty_bit_2[index] == 0))))? 1'd1 :
                                ((state == IDLE) || ((state == IDLE) && (core_wr_i == READ)) || ((state == WRITE_CACHE) && (dirty_bit_1[index] == 1 && dirty_bit_2[index] == 1)) || (state == UPDATE_CACHE)) ? 1'd0 : write_permission;
  
  
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            cache_metadata_1_i_lru_field <= 2'd0;
        end
        else begin
            cache_metadata_1_i_lru_field <= cache_metadata_1_i_lru_field_d;
        end
    end
    
    assign cache_metadata_1_i_lru_field_d = (state == READ_CACHE && present_in_1) || (state == WRITE_CACHE && present_in_1 && !dirty_bit_1[index]) || 
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b01 && !dirty_bit_1[index] && dirty_bit_2[index]) || 
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b01 && !dirty_bit_1[index] && !dirty_bit_2[index] && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) || 
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b10 && !dirty_bit_1[index] && dirty_bit_2[index]) ||
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b10 && !dirty_bit_1[index] && !dirty_bit_2[index] && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ?
                                                ((cache_metadata_1_o_lru_field == cache_metadata_2_o_lru_field) ? 2'b01 :
                                                ((cache_metadata_1_o_lru_field == 2'b11) ? cache_metadata_1_o_lru_field : cache_metadata_1_o_lru_field + 1)) :
                                            (((state == READ_CACHE && present_in_2) || (state == WRITE_CACHE && present_in_2 && !dirty_bit_1[index]) || 
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b01 && dirty_bit_1[index] && !dirty_bit_2[index]) || 
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b01 && dirty_bit_1[index] && !dirty_bit_2[index] && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) || 
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b10 && dirty_bit_1[index] && !dirty_bit_2[index]) ||  
                                            (state == WAIT_MEM && gnt_and_rvalid && prev_state == 2'b10 && dirty_bit_1[index] && !dirty_bit_2[index] && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)))  &&
                                                (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field)) ? 2'b00 : cache_metadata_1_i_lru_field;
                                                
    
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            cache_metadata_2_i_lru_field <= 2'd0;
        end
        else begin
            cache_metadata_2_i_lru_field <= cache_metadata_2_i_lru_field_d;
        end
    end
    
    assign cache_metadata_2_i_lru_field_d = (cache_metadata_1_o_lru_field == cache_metadata_2_o_lru_field) &&
                                            (((state == READ_CACHE) && (present_in_1 == 1)) || ((state == WRITE_CACHE) && (present_in_1 == 1  && dirty_bit_1[index] == 0)) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 )) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 )) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0) &&  ( cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ||
                                             ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ) ? 2'b00:                          
                                            (cache_metadata_1_o_lru_field == cache_metadata_2_o_lru_field) &&
                                            (((state == READ_CACHE) && (present_in_2 == 1)) ||
                                            ((state == WRITE_CACHE) && ((present_in_2 == 1 && dirty_bit_2[index] == 0))) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0)) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 )) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0) &&  ( cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field))) ? 2'b01:                                           
                                            ((cache_metadata_1_i_lru_field != cache_metadata_2_i_lru_field) && (cache_metadata_2_o_lru_field < 2'b11)) && 
                                            (((state == READ_CACHE) && (present_in_2 == 1)) ||
                                            ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_2[index] == 0)) || 
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 )) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 )) ||
                                            ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0) &&  ( cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field))) ? cache_metadata_2_o_lru_field + 1 : cache_metadata_2_i_lru_field ;
    
                                               
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            cache_metadata_1_i_tag_field <= 22'd0;
        end
        else begin
            cache_metadata_1_i_tag_field <= cache_metadata_1_i_tag_field_d;
        end
    end
    
    
    assign cache_metadata_1_i_tag_field_d = (state == WAIT_MEM && gnt_and_rvalid == 1 &&
                                            ((prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1) ||
                                            (prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 && cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) ||
                                            (prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1) ||
                                            (prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0 && cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field))) ? 
                                            core_addr_i[31:10] : cache_metadata_1_i_tag_field;
                                                                                               

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            cache_metadata_2_i_tag_field <= 22'd0;
        end
        else begin
            cache_metadata_2_i_tag_field <= cache_metadata_2_i_tag_field_d;
        end
    end
    
     assign cache_metadata_2_i_tag_field_d =  ((state == WAIT_MEM) && (gnt_and_rvalid == 1) &&
                                              ((prev_state == 2'b01 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0) || 
                                              (prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 && cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) ||
                                              (prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0) ||
                                              (prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0 && cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field))) ? 
                                              core_addr_i[31:10] : cache_metadata_2_i_tag_field;
                                            
                                            
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            prev_state <= 3'd0;
        end
        else begin
            prev_state <= prev_state_d;
        end
    end
    
    assign prev_state_d = ((state ==  READ_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 0) 
                                                  || (present_in_2 == 0 && dirty_bit_2[index] == 0) 
                                                  || ((present_in_1 == 0 && dirty_bit_1[index] == 1) || (present_in_2 == 0 && dirty_bit_2[index] == 1)))) ? 2'b01:
                         ((state ==  WRITE_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 0) 
                                                  || (present_in_2 == 0 && dirty_bit_2[index] == 0) 
                                                  || ((present_in_1 == 0 && dirty_bit_1[index] == 1) || (present_in_2 == 0 && dirty_bit_2[index] == 1)))) ? 2'b10:
                         ((state == WAIT_MEM) && ((gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 ) 
                                                  || (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 1)
                                                  || (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0))) ? 2'b00: prev_state;
    
                                      
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            valid_bit_1 <= 128'd0;
        end
        else begin
            valid_bit_1 <= valid_bit_1_d;
        end
    end
    
    
    genvar i;
    generate
        for (i=0; i<128; i = i+ 1) begin
            assign valid_bit_1_d[i]    = (index == i)  ? (((state == WRITE_CACHE) && (present_in_1 == 1 && dirty_bit_1[index] == 0) && valid_bit_2[i] != 1) ||
                                                         ((state == UPDATE_MEM) &&( cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 )) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 )) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0) && ( cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field))) ?
                                                           1'd1: valid_bit_1[i] : valid_bit_1[i];
        end
    endgenerate

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            valid_bit_2 <= 128'd0;
        end
        else begin
            valid_bit_2 <= valid_bit_1_d;
        end
    end
    
        genvar j;
    generate
        for (j=0; j<128; j = j+ 1) begin
            assign valid_bit_2_d[j]    = (index == j)  ?  ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_1[index] == 0) && valid_bit_1[j] != 1) ||
                                                         ((state == UPDATE_MEM) && cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) ||
                                                         ((state == WAIT_MEM) && gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 ) ||
                                                         ((state == WAIT_MEM) && gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0  && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ||
                                                         ((state == WAIT_MEM) && gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 ) ||
                                                         ((state == WAIT_MEM) && gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0 && ( cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ?
                                                          1'd1: valid_bit_2[j] : valid_bit_2[j]; 
        end
    endgenerate

    wire [127:0] dirty_bit_1_d;

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            dirty_bit_1 <= 128'd0;
        end
        else begin
            dirty_bit_1 <= dirty_bit_1_d;
        end
    end
    
    
    genvar k;
    generate
        for (k=0; k<128; k = k+ 1) begin
            assign dirty_bit_1_d[k]    = (index == k)  ? ((state == WRITE_CACHE) && (present_in_1 == 1 && dirty_bit_1[index] == 0)) ? 1'b1 : 
                                                         (((state == UPDATE_MEM) && ( cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 )) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 )) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0) && ( cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field))) ? 1'd0 : dirty_bit_1[k] : dirty_bit_1[k];
                                                            
       end
    endgenerate

    wire [127:0] dirty_bit_2_d;

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            dirty_bit_2 <= 128'd0;
        end
        else begin
            dirty_bit_2 <= dirty_bit_2_d;
        end
    end
    
    
    genvar m;
    generate
        for (m=0; m<128; m = m+ 1) begin
            assign dirty_bit_2_d[m]    = (index == m)  ? ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_2[index] == 0)) ? 1'b1 : 
                                                         (((state == UPDATE_MEM) &&( cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 )) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 )) ||
                                                         ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0) && ( cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field))) ? 1'd0 : dirty_bit_2[m] : dirty_bit_2[m];
        end
    endgenerate

    wire [31:0] core_data_o_d;
    
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            core_data_o <= 3'd0;
        end
        else begin
            core_data_o <= core_data_o_d;
        end
    end
    
    
    assign core_data_o_d = ((state == READ_CACHE) && ((present_in_1 == 1))  && (word_offset_field == 2'b00)) ? cache_data_1_o[31:0] : 
                           ((state == READ_CACHE) && ((present_in_1 == 1)) && (word_offset_field == 2'b01)) ? cache_data_1_o[63:32]:
                           ((state == READ_CACHE) && ((present_in_1 == 1)) && ( word_offset_field == 2'b10))? cache_data_1_o[95:64]:
                           ((state == READ_CACHE) && ((present_in_1 == 1)) && ( word_offset_field == 2'b11)) ? cache_data_1_o[127:96]:
                           ((state == READ_CACHE) && ((present_in_2 == 1))  && (word_offset_field == 2'b00)) ? cache_data_2_o[31:0] : 
                           ((state == READ_CACHE) && ((present_in_2 == 1) ) && (word_offset_field == 2'b01)) ? cache_data_2_o[63:32]:
                           ((state == READ_CACHE) && ((present_in_2 == 1) ) && ( word_offset_field == 2'b10))? cache_data_2_o[95:64]:
                           ((state == READ_CACHE) && ((present_in_2 == 1) ) && ( word_offset_field == 2'b11)) ? cache_data_2_o[127:96]:
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_1 == 1) && (word_offset_field == 2'b00)) )? cache_data_1_o[31:0] : 
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_1 == 1) && (word_offset_field == 2'b01)) )? cache_data_1_o[63:32]: 
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_1 == 1) && ( word_offset_field == 2'b10)))? cache_data_1_o[95:64]: 
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_1 == 1) && ( word_offset_field == 2'b11)))? cache_data_1_o[127:96]:
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_2 == 1) && (word_offset_field == 2'b00)) )? cache_data_2_o[31:0] : 
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_2 == 1) && (word_offset_field == 2'b01)) )? cache_data_2_o[63:32]: 
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_2 == 1) && ( word_offset_field == 2'b10)))? cache_data_2_o[95:64]: 
                           ((state == UPDATE_CACHE) && (core_en_i == 1 && core_wr_i == READ && (present_in_2 == 1) && ( word_offset_field == 2'b11)))? cache_data_2_o[127:96] : core_data_o ;

wire [31:0] ram_addr_o_d; 

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            ram_addr_o <= 32'd0;
        end
        else begin
            ram_addr_o <= ram_addr_o_d;
        end
    end
    
    assign ram_addr_o_d = ((state == READ_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 0) || (present_in_2 == 0 && dirty_bit_2[index] == 0))) || 
                          ((state == WRITE_CACHE) && ((present_in_1 == 0 && dirty_bit_1[index] == 0) || (present_in_2 == 0 && dirty_bit_2[index] == 0))) ? core_addr_i :
                          ((state == UPDATE_MEM) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ? {cache_metadata_1_o[20:0], index, word_offset_field, byte_offset_field} :
                          ((state == UPDATE_MEM) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ? {cache_metadata_2_o[20:0], index, word_offset_field, byte_offset_field} : ram_addr_o;
                          
    wire [31:0] ram_wr_data_o_d; 

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            ram_wr_data_o <= 32'd0;
        end
        else begin
            ram_wr_data_o <= ram_wr_data_o_d;
        end
    end
    
    assign ram_wr_data_o_d = ((state == UPDATE_MEM) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field)) ? cache_data_1_o:
                             ((state == UPDATE_MEM) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field)) ? cache_data_2_o : ram_wr_data_o;


    wire [127:0] cache_data_1_i_d, cache_data_2_i_d;
    
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            cache_data_1_i <= 32'd0;
        end
        else begin
            cache_data_1_i <= cache_data_1_i_d;
        end
    end
    
    assign cache_data_1_i_d = ((state == WRITE_CACHE) && ((present_in_1 == 1 && dirty_bit_1[index] == 0))  && (word_offset_field == 2'b00)) ? {cache_data_1_o[127:32] ,core_data_i} : 
                              ((state == WRITE_CACHE) && ((present_in_1 == 1 && dirty_bit_1[index] == 0))  && (word_offset_field == 2'b01)) ? {cache_data_1_o[127:64] ,core_data_i, cache_data_1_o[31:0]} : 
                              ((state == WRITE_CACHE) && ((present_in_1 == 1 && dirty_bit_1[index] == 0))  && (word_offset_field == 2'b10)) ? {cache_data_1_o[127:96] ,core_data_i, cache_data_1_o[63:0]} : 
                              ((state == WRITE_CACHE) && ((present_in_1 == 1 && dirty_bit_1[index] == 0))  && (word_offset_field == 2'b11)) ? {core_data_i, cache_data_1_o[95:0]} : 
                              (((state == WAIT_MEM)  &&  gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1)) ? ram_rd_data_i:
                              (((state == WAIT_MEM)  &&  gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) )) ? ram_rd_data_i:
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 ) && (word_offset_field == 2'b00)) ? {ram_rd_data_i[127:32] ,core_data_i} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 ) && (word_offset_field == 2'b01)) ? {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]}  : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 ) && (word_offset_field == 2'b10)) ? {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 ) && (word_offset_field == 2'b11)) ? {core_data_i, ram_rd_data_i[95:0]} :
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) && (word_offset_field == 2'b00)) ? {ram_rd_data_i[127:32] ,core_data_i} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) && (word_offset_field == 2'b01)) ? {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]}  : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) && (word_offset_field == 2'b10)) ? {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) && (word_offset_field == 2'b11)) ? {core_data_i, ram_rd_data_i[95:0]} : cache_data_1_i;
                               
    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            cache_data_2_i <= 32'd0;
        end
        else begin
            cache_data_2_i <= cache_data_2_i_d;
        end
    end
    
    assign cache_data_2_i_d = ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_2[index] == 0)  && (word_offset_field == 2'b00)) ? {cache_data_2_o[127:32] ,core_data_i} : 
                              ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_2[index] == 0)  && (word_offset_field == 2'b01)) ? {cache_data_2_o[127:64] ,core_data_i, cache_data_2_o[31:0]} : 
                              ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_2[index] == 0)  && (word_offset_field == 2'b10)) ? {cache_data_2_o[127:96] ,core_data_i, cache_data_2_o[63:0]} : 
                              ((state == WRITE_CACHE) && (present_in_2 == 1 && dirty_bit_2[index] == 0)  && (word_offset_field == 2'b11)) ? {core_data_i, cache_data_2_o[95:0]} : 
                              ((state == WAIT_MEM)  &&  gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 1 &&  dirty_bit_2[index] == 0 ) ? ram_rd_data_i:
                              (((state == WAIT_MEM)  &&  gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0) && (dirty_bit_2[index] == 0 && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) )) ? ram_rd_data_i:
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 ) && (word_offset_field == 2'b00)) ? {ram_rd_data_i[127:32] ,core_data_i} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 ) && (word_offset_field == 2'b01)) ? {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]}  : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 ) && (word_offset_field == 2'b10)) ? {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 ) && (word_offset_field == 2'b11)) ? {core_data_i, ram_rd_data_i[95:0]} :
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) && (word_offset_field == 2'b00)) ? {ram_rd_data_i[127:32] ,core_data_i} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) && (word_offset_field == 2'b01)) ? {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]}  : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) && (word_offset_field == 2'b10)) ? {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]} : 
                              ((state == WAIT_MEM) && (gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) && (cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) && (word_offset_field == 2'b11)) ? {core_data_i, ram_rd_data_i[95:0]} : cache_data_2_i;
                               
    wire [31:0] ram_wr_strb_o_d; 

    always @(posedge clk_i or negedge rst_ni)    begin
        if (!rst_ni) begin
            ram_wr_strb_o <= 32'd0;
        end
        else begin
            ram_wr_strb_o <= ram_wr_strb_o_d;
        end
    end
    
    assign ram_wr_strb_o_d = (state ==UPDATE_MEM) ? 16'b1111_1111_1111_1111 : 16'd0;


endmodule

/*
  always @(posedge clk_i) begin
    if (rst_ni == 1'b1) begin
          $display("Reseting\n");
          req_o <= 0;
          state <= IDLE;
          sram_en_i <= 1'b0;
          core_stall_o <= 0;
          ram_we_o <= 0; 
          write_permission <= 0;
          //write_permission_tag <= 1;
          valid_bit_1 <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF ;
          valid_bit_2 <= 128'hFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFFF;
          dirty_bit_1 <= 128'b0;
          dirty_bit_2 <= 128'b0;
          cache_metadata_1_i_lru_field <= 3'b000;
          cache_metadata_2_i_lru_field <= 3'b000;
          cache_metadata_1_i_tag_field <= 22'd0;
          cache_metadata_2_i_tag_field <= 22'd0;
          prev_state <= 2'b00;
          cache_data_1_i <= 128'd0;
          cache_data_2_i <= 128'd0;
    end
    if (rst_ni != 1'b1) begin
         case (state)
            IDLE : begin
              if (core_en_i) begin
                if (core_wr_i == READ) begin
                    sram_en_i <= 1'b1;
                    //write_permission_tag <= 1; 
                    write_permission <= 0;
                    core_stall_o <= 0;
                    state <= READ_CACHE;
                end
                if (core_wr_i == WRITE) begin
                    sram_en_i <= 1'b1; 
                    write_permission <= 1;
                    //write_permission_tag <= 1;
                    core_stall_o <= 0;
                    state <= WRITE_CACHE;
                end
              end
              else
                state <= IDLE;
            end
            READ_CACHE : begin
                if (present_in_1 == 1) begin //OK
                    core_stall_o <= 0;
                    case (word_offset_field)
                        2'b00: core_data_o <= cache_data_1_o[31:0];
                        2'b01: core_data_o <= cache_data_1_o[63:32];
                        2'b10: core_data_o <= cache_data_1_o[95:64];
                        2'b11: core_data_o <= cache_data_1_o[127:96];
                    endcase
                    // Incremenent LRU field or keep at maximum
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b001;
                        cache_metadata_2_i_lru_field <= 3'b000;
                    end else begin
                        cache_metadata_1_i_lru_field <= (cache_metadata_1_o_lru_field == 3'b111)? 
                                                         cache_metadata_1_o_lru_field :
                                                         cache_metadata_1_o_lru_field + 1;
                    end
                        // Keep all other fields the same for safety
                    cache_metadata_1_i_tag_field <= tag_field;
                    state <= IDLE;
                end
                else if (present_in_2 == 1) begin //OK
                    core_stall_o <= 0;
                    case (word_offset_field)
                        2'b00: core_data_o <= cache_data_2_o[31:0];
                        2'b01: core_data_o <= cache_data_2_o[63:32];
                        2'b10: core_data_o <= cache_data_2_o[95:64];
                        2'b11: core_data_o <= cache_data_2_o[127:96];
                    endcase
                    // Incremenent LRU field or keep at maximum and if thay are same make them zero
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b000;
                        cache_metadata_2_i_lru_field <= 3'b001;
                    end else begin
                        cache_metadata_2_i_lru_field <= (cache_metadata_2_o_lru_field == 3'b111)? 
                                                         cache_metadata_2_o_lru_field :
                                                         cache_metadata_2_o_lru_field + 1;
                    end
                    cache_metadata_2_i_tag_field <= tag_field;
                    state <= IDLE;
                end 
                else if (present_in_1 == 0 && dirty_bit_1[index] == 0) begin //OK
                    ram_addr_o <= core_addr_i;
                    ram_we_o <= 0;
                    req_o <= 1;
                    core_stall_o <= 1;
                    write_permission <= 1;
                    prev_state <= 2'b01;
                    state <= WAIT_MEM;  //mevcut degil ve temizse eger main_mem'den okuma yapicak yani uzerine yazým yapabilirim bi yerde depolamama gerek yok
                end
                else if (present_in_2 == 0 && dirty_bit_2[index] == 0) begin // OK
                    ram_addr_o <= core_addr_i;
                    ram_we_o <= 0;
                    req_o <= 1;
                    core_stall_o <= 1;
                    write_permission <= 1;
                    prev_state <= 2'b01; // 01 == read 10 = write 00 = no state 
                    state <= WAIT_MEM;
                end
                else if ((present_in_1 == 0 && dirty_bit_1[index] == 1) || (present_in_2 == 0 && dirty_bit_2[index] == 1)) begin //temiz degilse ilk olarak memory'i oradakiyle guncellemem gerekicek. yani okumaya geldim no hit mem'den birþey gelcek ama orasý daha mem'e kaydedilmemiþ
                    core_stall_o <= 1;
                    ram_we_o <= 1;
                    req_o <= 1;
                    state <= UPDATE_MEM;
                    prev_state <= 2'b01; //gerek olmayabilir
                end
            end
            WRITE_CACHE : begin
                if (present_in_1 == 1 && dirty_bit_1[index] == 0) begin //OK
                    core_stall_o <= 0;
                    case (word_offset_field)
                        2'b00: cache_data_1_i <= {cache_data_1_o[127:32] ,core_data_i};
                        2'b01: cache_data_1_i <= {cache_data_1_o[127:64] ,core_data_i, cache_data_1_o[31:0]};
                        2'b10: cache_data_1_i <= {cache_data_1_o[127:96] ,core_data_i, cache_data_1_o[63:0]};
                        2'b11: cache_data_1_i <= {core_data_i, cache_data_1_o[95:0]};
                    endcase
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b001;
                        cache_metadata_2_i_lru_field <= 3'b000;
                    end else begin
                        cache_metadata_1_i_lru_field <= (cache_metadata_1_o_lru_field == 3'b111)? 
                                                         cache_metadata_1_o_lru_field :
                                                         cache_metadata_1_o_lru_field + 1;
                    end
                    valid_bit_1[index] <= 1;
                    cache_metadata_1_i_tag_field <= tag_field; 
                    dirty_bit_1[index] <= 1;
                    state <= IDLE;
                end
                else if (present_in_2 == 1 && dirty_bit_2[index] == 0) begin //OK
                    core_stall_o <= 0;
                    case (word_offset_field)
                        2'b00: cache_data_2_i <= {cache_data_2_o[127:32] ,core_data_i};
                        2'b01: cache_data_2_i <= {cache_data_2_o[127:64] ,core_data_i, cache_data_2_o[31:0]};
                        2'b10: cache_data_2_i <= {cache_data_2_o[127:96] ,core_data_i, cache_data_2_o[63:0]};
                        2'b11: cache_data_2_i <= {core_data_i, cache_data_2_o[95:0]};
                    endcase
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b000;
                        cache_metadata_2_i_lru_field <= 3'b001;
                    end else begin
                        cache_metadata_2_i_lru_field <= (cache_metadata_2_o_lru_field == 3'b111)? 
                                                         cache_metadata_2_o_lru_field :
                                                         cache_metadata_2_o_lru_field + 1;
                    end
                    valid_bit_2[index] <= 1;
                    cache_metadata_2_i_tag_field <= tag_field;
                    dirty_bit_2[index] <= 1;
                    state <= IDLE; 
                end
                else if (present_in_1 == 0 &&  dirty_bit_1[index] == 0) begin //OK
                    ram_addr_o <= core_addr_i;
                    ram_we_o <= 0;
                    req_o <= 1;
                    core_stall_o <= 1;
                    prev_state <= 2'b10;
                    state <= WAIT_MEM;
                end
                else if (present_in_2 == 0 && dirty_bit_2[index] == 0) begin //OK
                    ram_addr_o <= core_addr_i;
                    ram_we_o <= 0;
                    req_o <= 1;
                    core_stall_o <= 1;
                    prev_state <= 2'b10;
                    state <= WAIT_MEM;
                end
                else if (dirty_bit_1[index] == 1 || dirty_bit_2[index] == 1) begin //OK
                    write_permission <= 0;
                    core_stall_o <= 1;
                    req_o <= 1; 
                    ram_we_o <= 1;
                    prev_state <= 2'b10;
                    state <= UPDATE_MEM; //g?nderice?im adresi burda belirlesem asl?nda g?zel olabilir.
                end
            end
            UPDATE_MEM : begin
                if (gnt_and_rvalid == 1) begin
                    if (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) begin
                        ram_wr_data_o <= cache_data_1_o;
                        ram_addr_o <= {cache_metadata_1_o[20:0], index, word_offset_field, byte_offset_field}; //bu sat?rlar hi? g?venilir de?il. ?zelllikle word_ofset_field ve byte_offset
                        valid_bit_1 <= 1;
                        dirty_bit_1 <= 0;
                        ram_wr_strb_o <= 16'b1111_1111_1111_1111;
                        state <= WAIT_MEM;
                    end else begin
                        ram_wr_data_o <= cache_data_2_o;
                        ram_addr_o <= {cache_metadata_2_o[20:0], index, word_offset_field, byte_offset_field};
                        valid_bit_2 <= 1;
                        dirty_bit_2 <= 0;
                        ram_wr_strb_o <= 16'b1111_1111_1111_1111;
                        state <= WAIT_MEM; //CHECKLENDI
                    end
                end
            end
            UPDATE_CACHE : begin
                if(core_en_i == 1 && core_wr_i == READ && present_in_1 == 1 ) begin //core_wr_i i?in prew state tutan bir?ey laz?m asl?nda ??nk? de?i?iyor clk cycle sonra
                    write_permission <= 0;
                    core_stall_o <= 0;
                    case (word_offset_field)
                        2'b00: core_data_o <= cache_data_1_o[31:0];
                        2'b01: core_data_o <= cache_data_1_o[63:32];
                        2'b10: core_data_o <= cache_data_1_o[95:64];
                        2'b11: core_data_o <= cache_data_1_o[127:96];
                    endcase
                    cache_metadata_1_i_tag_field <= tag_field;
                    state <= IDLE;
                end
                else if (core_en_i == 1 && core_wr_i == READ &&  present_in_2 == 1) begin
                    core_stall_o <= 0;
                    case (word_offset_field)
                        2'b00: core_data_o <= cache_data_2_o[31:0];
                        2'b01: core_data_o <= cache_data_2_o[63:32];
                        2'b10: core_data_o <= cache_data_2_o[95:64];
                        2'b11: core_data_o <= cache_data_2_o[127:96];
                    endcase
                    write_permission <= 0;
                    cache_metadata_2_i_tag_field <= tag_field;
                    state <= IDLE;
                end
            end
            WAIT_MEM : begin
                if(gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 ) begin
                    ram_we_o <= 0;
                    req_o <= 0;
                    //prev_state <= 2'b00;
                    cache_data_1_i <= ram_rd_data_i;
                    cache_metadata_1_i_tag_field <= core_addr_i[31:11]; 
                    valid_bit_1[index] <= 1;
                    dirty_bit_1[index] <= 0;
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b001;
                        cache_metadata_2_i_lru_field <= 3'b000;
                    end else begin
                        cache_metadata_1_i_lru_field <= (cache_metadata_1_o_lru_field == 3'b111)? 
                                                         cache_metadata_1_o_lru_field :
                                                         cache_metadata_1_o_lru_field + 1;
                    end
                    state <= UPDATE_CACHE; //ARTIK PRESENT IN 1 SO THiS iS FOR READ OPTiON NECESSERY
                end else if(gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 1 && dirty_bit_2[index] == 0 ) begin
                    ram_we_o <= 0;
                    req_o <= 0;
                    //prev_state <= 2'b00;
                    cache_data_2_i <= ram_rd_data_i;
                    cache_metadata_2_i_tag_field <= core_addr_i[31:11];
                    valid_bit_2[index] <= 1;
                    dirty_bit_2[index] <= 0;
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b000;
                        cache_metadata_2_i_lru_field <= 3'b001;
                    end else begin
                        cache_metadata_2_i_lru_field <= (cache_metadata_2_o_lru_field == 3'b111)? 
                                                         cache_metadata_2_o_lru_field :
                                                         cache_metadata_2_o_lru_field + 1;
                    end
                    state <= UPDATE_CACHE;
                end else if(gnt_and_rvalid == 1 && prev_state == 2'b01 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 0 ) begin
                    //prev_state <= 2'b00;
                    if (cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) begin
                        ram_we_o <= 0;
                        req_o <= 0;
                        cache_data_1_i <= ram_rd_data_i;
                        cache_metadata_1_i_tag_field <= core_addr_i[31:11];
                        valid_bit_1[index] <= 1;
                        dirty_bit_1[index] <= 0;
                        if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                            cache_metadata_1_i_lru_field <= 3'b001;
                            cache_metadata_2_i_lru_field <= 3'b000;
                        end else begin
                            cache_metadata_1_i_lru_field <= (cache_metadata_1_o_lru_field == 3'b111)? 
                                                         cache_metadata_1_o_lru_field :
                                                         cache_metadata_1_o_lru_field + 1;
                        end
                        state <= UPDATE_CACHE;
                    end else begin
                        ram_we_o <= 0;
                        req_o <= 0;                        
                        cache_data_2_i <= ram_rd_data_i;
                        cache_metadata_2_i_tag_field <= core_addr_i[31:11];
                        valid_bit_2[index] <= 1;
                        dirty_bit_2[index] <= 0;
                        if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                            cache_metadata_1_i_lru_field <= 3'b000;
                            cache_metadata_2_i_lru_field <= 3'b001;
                        end else begin
                            cache_metadata_2_i_lru_field <= (cache_metadata_2_o_lru_field == 3'b111)? 
                                                            cache_metadata_2_o_lru_field :
                                                            cache_metadata_2_o_lru_field + 1;
                        end
                        state <= UPDATE_CACHE;
                    end
                end else if(gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_1[index] == 0 && dirty_bit_2[index] == 1 ) begin 
                    ram_we_o <= 0;  
                    core_stall_o <= 0;
                    prev_state <= 2'b00;
                    req_o <= 0;
                    case (word_offset_field)
                        2'b00: cache_data_1_i <= {ram_rd_data_i[127:32] ,core_data_i};
                        2'b01: cache_data_1_i <= {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]};
                        2'b10: cache_data_1_i <= {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]};
                        2'b11: cache_data_1_i <= {core_data_i, ram_rd_data_i[95:0]};
                    endcase
                    cache_metadata_1_i_tag_field <= core_addr_i[31:11]; 
                    valid_bit_1[index] <= 1;
                    dirty_bit_1[index] <= 0;
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b001;
                        cache_metadata_2_i_lru_field <= 3'b000;
                    end else begin
                        cache_metadata_1_i_lru_field <= (cache_metadata_1_o_lru_field == 3'b111)? 
                                                         cache_metadata_1_o_lru_field :
                                                         cache_metadata_1_o_lru_field + 1;
                    end
                    state <= IDLE;
                end else if(gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 1) begin
                    ram_we_o <= 0;  
                    core_stall_o <= 0;
                    prev_state <= 2'b00;
                    req_o <= 0;
                    case (word_offset_field)
                        2'b00: cache_data_2_i <= {ram_rd_data_i[127:32] ,core_data_i};
                        2'b01: cache_data_2_i <= {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]};
                        2'b10: cache_data_2_i <= {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]};
                        2'b11: cache_data_2_i <= {core_data_i, ram_rd_data_i[95:0]};
                    endcase
                    cache_metadata_2_i_tag_field <= core_addr_i[31:11];
                    valid_bit_2[index] <= 1;
                    dirty_bit_2[index] <= 0;
                    if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                        cache_metadata_1_i_lru_field <= 3'b000;
                        cache_metadata_2_i_lru_field <= 3'b001;
                    end else begin
                        cache_metadata_2_i_lru_field <= (cache_metadata_2_o_lru_field == 3'b111)? 
                                                         cache_metadata_2_o_lru_field :
                                                         cache_metadata_2_o_lru_field + 1;
                    end
                    state <= IDLE;
                end else if(gnt_and_rvalid == 1 && prev_state == 2'b10 && dirty_bit_2[index] == 0 && dirty_bit_1[index] == 0) begin
                    prev_state <= 2'b00;
                    if ( cache_metadata_1_o_lru_field <= cache_metadata_2_o_lru_field) begin //o olacak buralar ama bi deneyem
                        req_o <= 0;
                        ram_we_o <= 0;                    
                        core_stall_o <= 0;
                        case (word_offset_field)
                            2'b00: cache_data_1_i <= {ram_rd_data_i[127:32] ,core_data_i};
                            2'b01: cache_data_1_i <= {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]};
                            2'b10: cache_data_1_i <= {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]};
                            2'b11: cache_data_1_i <= {core_data_i, ram_rd_data_i[95:0]};
                        endcase
                        cache_metadata_1_i_tag_field <= core_addr_i[31:11];
                        valid_bit_1[index] <= 1;
                        dirty_bit_1[index] <= 0;
                        if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                            cache_metadata_1_i_lru_field <= 3'b000;
                            cache_metadata_2_i_lru_field <= 3'b001;
                        end else begin
                            cache_metadata_2_i_lru_field <= (cache_metadata_2_o_lru_field == 3'b111)? 
                                                         cache_metadata_2_o_lru_field :
                                                         cache_metadata_2_o_lru_field + 1;
                        end
                        state <= IDLE;
                    end else if ( cache_metadata_1_o_lru_field > cache_metadata_2_o_lru_field) begin
                        req_o <= 0;
                        ram_we_o <= 0;                    
                        core_stall_o <= 0;
                        case (word_offset_field)
                            2'b00: cache_data_2_i <= {ram_rd_data_i[127:32] ,core_data_i};
                            2'b01: cache_data_2_i <= {ram_rd_data_i[127:64] ,core_data_i, ram_rd_data_i[31:0]};
                            2'b10: cache_data_2_i <= {ram_rd_data_i[127:96] ,core_data_i, ram_rd_data_i[63:0]};
                            2'b11: cache_data_2_i <= {core_data_i, ram_rd_data_i[95:0]};
                        endcase
                        cache_metadata_2_i_tag_field <= core_addr_i[31:11];
                        valid_bit_2[index] <= 1;
                        dirty_bit_2[index] <= 0;
                        if (cache_metadata_1_i_lru_field == cache_metadata_2_i_lru_field) begin
                            cache_metadata_1_i_lru_field <= 3'b000;
                            cache_metadata_2_i_lru_field <= 3'b001;
                        end else begin
                            cache_metadata_2_i_lru_field <= (cache_metadata_2_o_lru_field == 3'b111)? 
                                                            cache_metadata_2_o_lru_field :
                                                            cache_metadata_2_o_lru_field + 1;
                        end
                        state <= IDLE;
                    end
                end else begin
                    state <= WAIT_MEM;
                end
            end
        endcase
    end
  end 
endmodule
*/

