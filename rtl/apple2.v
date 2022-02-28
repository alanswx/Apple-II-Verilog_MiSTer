//-----------------------------------------------------------------------------
// Top level of an Apple //e
//
// Based on:
// Top level of an Apple ][+
//
// Stephen A. Edwards, sedwards@cs.columbia.edu
//
//-----------------------------------------------------------------------------

module apple2(
    CLK_14M,
    CLK_2M,
    CPU_WAIT,
    PHASE_ZERO,
    FLASH_CLK,
    reset,
    cpu,
    ADDR,
    ram_addr,
    D,
    ram_do,
    aux,
    PD,
    CPU_WE,
    IRQ_n,
    NMI_n,
    ram_we,
    VIDEO,
    COLOR_LINE,
    HBL,
    VBL,
    K,
    READ_KEY,
    AKD,
    AN,
    GAMEPORT,
    PDL_STROBE,
    STB,
    IO_SELECT,
    DEVICE_SELECT,
    IO_STROBE,
    speaker
);
    input         CLK_14M;		// 14.31818 MHz master clock
    output        CLK_2M;
    input         CPU_WAIT;
    output        PHASE_ZERO;
    input         FLASH_CLK;		// approx. 2 Hz flashing char clock
    input         reset;
    input         cpu;		// 0 - 6502, 1 - 65C02
    output [15:0] ADDR;		// CPU address
    output [17:0] ram_addr;		// RAM address
    output [7:0]  D;		// Data to RAM
    input [15:0]  ram_do;		// Data from RAM (lo byte: MAIN RAM, hi byte: AUX RAM)
    output reg    aux;		// Write to MAIN or AUX RAM
    input [7:0]   PD;		// Data to CPU from peripherals
    output        CPU_WE;
    input         IRQ_n;
    input         NMI_n;
    output        ram_we;		// RAM write enable
    output        VIDEO;
    output        COLOR_LINE;
    output        HBL;
    output        VBL;
    input [7:0]   K;		// Keyboard data
    output reg    READ_KEY;		// Processor has read key
    input         AKD;		// Any key down flag
    output [3:0]  AN;		// Annunciator outputs
    // GAMEPORT input bits:
    //  7    6    5    4    3   2   1    0
    // pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
    input [7:0]   GAMEPORT;
    output reg    PDL_STROBE;		// Pulses high when C07x read
    output reg    STB;		// Pulses high when C04x read
    output [7:0]  IO_SELECT;
    output [7:0]  DEVICE_SELECT;
    output reg    IO_STROBE;
    output        speaker;		// One-bit speaker output
    
    
    // 14.31818 MHz master clock
    // Data from RAM
    // Low-frequency flashing text clock
    // 14.31818 MHz master clock
    // 2 MHz signal in phase with PHI0
    // 1.0 MHz processor clock
    // 3.579545 MHz colorburst
    
    // Horizontal blanking
    // Vertical blanking
    // Composite blanking
    
    // Clocks
    wire          CLK_7M;
    wire          Q3;
    wire          RAS_N;
    wire          CAS_N;
    wire          AX;
    reg           PHASE_ZERO_D;
    wire          COLOR_REF;
    wire          CPU_EN;
    reg           CPU_EN_POST;
    
    // From the timing generator
    wire [15:0]   VIDEO_ADDRESS;
    wire          LDPS_N;
    wire          WNDW_N;
    wire          GR2;
    wire          SEGA;
    wire          SEGB;
    wire          SEGC;
    
    // Soft switches
    reg [7:0]     soft_switches;
    wire          TEXT_MODE;
    wire          MIXED_MODE;
    wire          PAGE2;
    wire          HIRES_MODE;
    wire          DHIRES_MODE;
    
    // ][e auxilary switches
    reg           RAMRD;
    reg           RAMWRT;
    reg           CXROM;
    reg           STORE80;
    reg           C3ROM;
    reg           C8ROM;
    reg           ALTZP;
    reg           ALTCHAR;
    reg           COL80;
    reg           SF_D;
    
    // CPU signals
    wire [7:0]    D_IN;
    wire [7:0]    D_OUT;
    wire [15:0]   A;
    wire [23:0]   T65_A;
    wire [7:0]    T65_DI;
    wire [7:0]    T65_DO;
    wire          T65_WE_N;
    wire [15:0]   R65C02_A;
    wire [7:0]    R65C02_DO;
    wire          R65C02_WE_N;
    wire          we;
    
    // Main ROM signals
    wire [7:0]    rom_out;
    wire [13:0]   rom_addr;
    
    // Address decoder signals
    reg           RAM_SELECT;
    reg           KEYBOARD_SELECT;
    reg           TAPE_OUT;
    reg           SPEAKER_SELECT;
    reg           SOFTSWITCH_SELECT;
    reg           ROM_SELECT;
    reg           GAMEPORT_SELECT;
    //signal IO_STROBE : std_logic;
    reg           HRAM_CONTROL;
    reg           C01X_SELECT;
    
    // Speaker signal
    reg           speaker_sig;
    
    reg [7:0]     CPU_DL;		// Latched RAM data
    wire [7:0]    VIDEO_DL;
    reg [15:0]    VIDEO_DL_LATCH;
    
    // Bank Switched RAM signals
    wire          Dxxx;
    reg           HRAM_READ;
    reg           HRAM_PRE_WR;
    reg           HRAM_WR_N;
    reg           HRAM_BANK1;
    wire [17:0]   CPU_RAM_ADDR;
    
    wire          HRAM_READ_EN;
    wire          HRAM_WRITE_EN;
    
    reg [7:0]     ioselect;
    reg [7:0]     devselect;
    
    wire          R_W_n;
    
    // ramcard
    wire [17:0]   card_addr;
    wire          card_ram_rd;
    wire          card_ram_we;
    wire          ram_card_read;
    wire          ram_card_write;
    wire          ram_card_sel;
    
    assign CLK_2M = Q3;
    
    assign ram_addr = (PHASE_ZERO == 1'b1) ? CPU_RAM_ADDR : 
                      {2'b00, VIDEO_ADDRESS};
    assign ram_we = (PHASE_ZERO == 1'b1) ? ((we & RAM_SELECT) | (we & (HRAM_WRITE_EN | ram_card_write))) : 
                    1'b0;
    assign CPU_WE = we;
    
    // ramcard  
    
    ramcard ram_card_D(
        .clk(CLK_14M),
        .reset_in(reset),
        .addr(A),
        .ram_addr(card_addr),
        .card_ram_we(card_ram_we),
        .card_ram_rd(card_ram_rd)
    );
    
    assign ram_card_read = ROM_SELECT & card_ram_rd;
    assign ram_card_write = ROM_SELECT & card_ram_we;
    assign ram_card_sel = (we == 1'b1) ? ram_card_write : 
                          ram_card_read;
    
    
    always @(posedge CLK_14M)
    begin: RAM_data_latch
        
        begin
            if (AX == 1'b1 & CAS_N == 1'b0 & RAS_N == 1'b1 & Q3 == 1'b0)
            begin
                // Latch video data at Phase 1, CPU data at Phase 0
                if (PHASE_ZERO == 1'b0)
                    VIDEO_DL_LATCH <= ram_do;
                else if (aux == 1'b0)
                    CPU_DL <= ram_do[7:0];
                else
                    CPU_DL <= ram_do[15:8];
            end
        end
    end
    assign VIDEO_DL = (PHASE_ZERO == 1'b0) ? VIDEO_DL_LATCH[7:0] : 
                      VIDEO_DL_LATCH[15:8];
    
    assign ADDR = A;
    assign D = D_OUT;
    
    assign IO_SELECT = ioselect;
    assign DEVICE_SELECT = devselect;
    
    // Address decoding
    //  rom_addr <= (A(13) and A(12)) & (not A(12)) & A(11 downto 0);
    assign rom_addr = A[13:0];
    
    
    //always @(A or C3ROM or C8ROM or CXROM)
    always @(*)
    begin: address_decoder
        ROM_SELECT = 1'b0;
        RAM_SELECT = 1'b0;
        KEYBOARD_SELECT = 1'b0;
        C01X_SELECT = 1'b0;
        TAPE_OUT = 1'b0;
        SPEAKER_SELECT = 1'b0;
        SOFTSWITCH_SELECT = 1'b0;
        GAMEPORT_SELECT = 1'b0;
        PDL_STROBE = 1'b0;
        STB = 1'b0;
        HRAM_CONTROL = 1'b0;
        ioselect = 8'b0;
        devselect = 8'b0;
        IO_STROBE = 1'b0;
        case (A[15:14])
            2'b00, 2'b01, 2'b10 :		// 0000 - BFFF
                RAM_SELECT = 1'b1;
            2'b11 :		// C000 - FFFF
                case (A[13:12])
                    2'b00 :		// C000 - CFFF
                        case (A[11:8])
                            4'h0 :		// C000 - C0FF
                                case (A[7:4])
                                    4'h0 :		// C000 - C00F
                                        KEYBOARD_SELECT = 1'b1;
                                    4'h1 :		// C010 - C01F
                                        C01X_SELECT = 1'b1;
                                    4'h2 :		// C020 - C02F
                                        TAPE_OUT = 1'b1;
                                    4'h3 :		// C030 - C03F
                                        SPEAKER_SELECT = 1'b1;
                                    4'h4 :		// C040 - C04F
                                        STB = 1'b1;
                                    4'h5 :		// C050 - C05F
                                        SOFTSWITCH_SELECT = 1'b1;
                                    4'h6 :		// C060 - C06F
                                        GAMEPORT_SELECT = 1'b1;
                                    4'h7 :		// C070 - C07F
                                        PDL_STROBE = 1'b1;
                                    4'h8 :		// C080 - C08F
                                        HRAM_CONTROL = 1'b1;
                                    4'h9, 4'hA, 4'hB, 4'hC, 4'hD, 4'hE, 4'hF :		// C090 - C0FF
                                        devselect[(A[6:4])] = 1'b1;
                                    default :
                                        ;
                                endcase
                            4'h1, 4'h2, 4'h4, 4'h5, 4'h6, 4'h7 :		// C100 - C2FF, C400-C7FF
                                if (CXROM == 1'b1)
                                    ROM_SELECT = 1'b1;
                                else
                                    ioselect[(A[10:8])] = 1'b1;
                            4'h3 :		// C300 - C3FF
                                if (CXROM == 1'b1 | C3ROM == 1'b0)
                                    ROM_SELECT = 1'b1;
                                else
                                    ioselect[(A[10:8])] = 1'b1;
                            4'h8, 4'h9, 4'hA, 4'hB, 4'hC, 4'hD, 4'hE, 4'hF :		// C800 - CFFF
begin
//$display("inside C800-CFFF");
                                if (CXROM == 1'b1 | C8ROM == 1'b1)
                                    ROM_SELECT = 1'b1;
                                else
                                    IO_STROBE = 1'b1;
end
                            default :
                                ;
                        endcase
                    2'b01, 2'b10, 2'b11 :		// D000 - FFFF
                        ROM_SELECT = 1'b1;
                    default :
                        ;
                endcase
            default :
                ;
        endcase
    end
    
    
    //always @(A or we or RAMRD or RAMWRT or STORE80 or HIRES_MODE or PAGE2 or ALTZP or ram_card_sel)
    always @(*)
    begin: aux_ctrl
        aux = 1'b0;
        if (ram_card_sel == 1'b1)
            aux = 1'b0;
        else if (A[15:9] == 7'b0000000 | A[15:14] == 2'b11)		// Page 00,01,C0-FF
            aux = ALTZP;
        else if (A[15:10] == 6'b000001)		// Page 04-07
            aux = (STORE80 & PAGE2) | ((~STORE80) & ((RAMRD & (~we)) | (RAMWRT & we)));
        else if (A[15:13] == 3'b001)		// Page 20-3F
            aux = (STORE80 & PAGE2 & HIRES_MODE) | (((~STORE80) | (~HIRES_MODE)) & ((RAMRD & (~we)) | (RAMWRT & we)));
        else
            aux = (RAMRD & (~we)) | (RAMWRT & we);
    end
    
    
    always @(posedge CLK_14M)
    begin: speaker_ctrl
        
        begin
            if (CPU_EN_POST == 1'b1 & SPEAKER_SELECT == 1'b1)
                speaker_sig <= (~speaker_sig);
        end
    end
    
    
    always @(posedge CLK_14M)
    begin: softswitches
        
        begin
            if (CPU_EN_POST == 1'b1 & SOFTSWITCH_SELECT == 1'b1)
                soft_switches[(A[3:1])] <= A[0];
        end
    end
    
    assign TEXT_MODE = soft_switches[0];
    assign MIXED_MODE = soft_switches[1];
    assign PAGE2 = soft_switches[2];
    assign HIRES_MODE = soft_switches[3];
    assign AN = soft_switches[7:4];
    assign DHIRES_MODE = AN[3];
    
    
    always @(posedge CLK_14M )
    begin: hram_ctrl
        if (reset == 1'b1)
        begin
            HRAM_PRE_WR <= 1'b0;
            HRAM_READ <= 1'b0;
            HRAM_WR_N <= 1'b0;
            HRAM_BANK1 <= 1'b0;
        end
        else 
        begin
            if (CPU_EN_POST == 1'b1 & HRAM_CONTROL == 1'b1)
            begin
                HRAM_BANK1 <= A[3];
                HRAM_PRE_WR <= A[0] & (~we);
                if ((HRAM_PRE_WR & (~we) & A[0]) == 1'b1)
                    HRAM_WR_N <= 1'b0;
                else if (A[0] == 1'b0)
                    HRAM_WR_N <= 1'b1;
                HRAM_READ <= (~(A[0] ^ A[1]));
            end
        end
    end
    
    assign Dxxx = (A[15:12] == 4'hD) ? 1'b1 : 
                  1'b0;
    assign CPU_RAM_ADDR = (ram_card_sel == 1'b1) ? card_addr : 
                          {2'b00, A[15:13], (A[12] & (~(HRAM_BANK1 & Dxxx))), A[11:0]};
    assign HRAM_READ_EN = HRAM_READ & A[15] & A[14] & (A[13] | A[12]);		// Dxxx-Fxxx
    assign HRAM_WRITE_EN = (~HRAM_WR_N) & A[15] & A[14] & (A[13] | A[12]);		// Dxxx-Fxxx
    
    
    always @(posedge CLK_14M )
    begin: softswitches_IIe
        if (reset == 1'b1)
        begin
            STORE80 <= 1'b0;
            RAMRD <= 1'b0;
            RAMWRT <= 1'b0;
            CXROM <= 1'b0;
            ALTZP <= 1'b0;
            C3ROM <= 1'b0;
            C8ROM <= 1'b0;
            COL80 <= 1'b0;
            ALTCHAR <= 1'b0;
        end
        else 
        begin
            READ_KEY <= 1'b0;
            if (A[15:8] == 8'hC3 & C3ROM == 1'b0)
                C8ROM <= 1'b1;
            else if (A == 16'hCFFF)
                C8ROM <= 1'b0;
            if (CPU_EN_POST == 1'b1 & KEYBOARD_SELECT == 1'b1 & we == 1'b1)
                case (A[3:1])
                    3'b000 :
                        STORE80 <= A[0];
                    3'b001 :
                        RAMRD <= A[0];
                    3'b010 :
                        RAMWRT <= A[0];
                    3'b011 :
                        CXROM <= A[0];
                    3'b100 :
                        ALTZP <= A[0];
                    3'b101 :
                        C3ROM <= A[0];
                    3'b110 :
                        COL80 <= A[0];
                    3'b111 :
                        ALTCHAR <= A[0];
                    default :
                        ;
                endcase
            else if (C01X_SELECT == 1'b1 & we == 1'b0)
                case (A[3:0])
                    4'h0 :
                        begin
                            SF_D <= AKD;
                            READ_KEY <= 1'b1;
                        end
                    4'h1 :
                        SF_D <= (~HRAM_BANK1);
                    4'h2 :
                        SF_D <= HRAM_READ;
                    4'h3 :
                        SF_D <= RAMRD;
                    4'h4 :
                        SF_D <= RAMWRT;
                    4'h5 :
                        SF_D <= CXROM;
                    4'h6 :
                        SF_D <= ALTZP;
                    4'h7 :
                        SF_D <= C3ROM;
                    4'h8 :
                        SF_D <= STORE80;
                    4'h9 :
                        SF_D <= (~VBL);
                    4'hA :
                        SF_D <= TEXT_MODE;
                    4'hB :
                        SF_D <= MIXED_MODE;
                    4'hC :
                        SF_D <= PAGE2;
                    4'hD :
                        SF_D <= HIRES_MODE;
                    4'hE :
                        SF_D <= ALTCHAR;
                    4'hF :
                        SF_D <= COL80;
                    default :
                        ;
                endcase
            else if (C01X_SELECT == 1'b1 & we == 1'b1)
                READ_KEY <= 1'b1;
        end
    end
    
    assign speaker = speaker_sig;
    
    assign D_IN = (RAM_SELECT == 1'b1 | HRAM_READ_EN == 1'b1 | ram_card_read == 1'b1) ? CPU_DL : 		// RAM
                  (KEYBOARD_SELECT == 1'b1) ? K : 		// Keyboard
                  (C01X_SELECT == 1'b1) ? {SF_D, K[6:0]} : 		// ][e softswitches
                  (GAMEPORT_SELECT == 1'b1) ? {GAMEPORT[(A[2:0])], VIDEO_DL[6:0]} : 		// Gameport
                  (ROM_SELECT == 1'b1) ? rom_out : 		// ROMs
                  (TAPE_OUT == 1'b1 | SPEAKER_SELECT == 1'b1 | STB == 1'b1 | SOFTSWITCH_SELECT == 1'b1 | PDL_STROBE == 1'b1 | HRAM_CONTROL == 1'b1 | A == 16'hCFFF) ? VIDEO_DL : 		// Floating bus
                  PD;		// Peripherals
    
    
    timing_generator timing(
        .CLK_14M(CLK_14M),
        .VID7M(CLK_7M),
        .CAS_N(CAS_N),
        .RAS_N(RAS_N),
        .Q3(Q3),
        .AX(AX),
        .PHI0(PHASE_ZERO),
        .COLOR_REF(COLOR_REF),
        .TEXT_MODE(TEXT_MODE),
        .PAGE2(PAGE2),
        .HIRES_MODE(HIRES_MODE),
        .MIXED_MODE(MIXED_MODE),
        .COL80(COL80),
        .STORE80(STORE80),
        .DHIRES_MODE(DHIRES_MODE),
        .VID7(VIDEO_DL[7]),
        .VIDEO_ADDRESS(VIDEO_ADDRESS),
        .SEGA(SEGA),
        .SEGB(SEGB),
        .SEGC(SEGC),
        .GR1(COLOR_LINE),
        .GR2(GR2),
        .VBLANK(VBL),
        .HBLANK(HBL),
        .WNDW_N(WNDW_N),
        .LDPS_N(LDPS_N)
    );
    
    
    video_generator video_display(
        .CLK_14M(CLK_14M),
        .CLK_7M(CLK_7M),
        .GR2(GR2),
        .SEGA(SEGA),
        .SEGB(SEGB),
        .SEGC(SEGC),
        .ALTCHAR(ALTCHAR),
        .WNDW_N(WNDW_N),
        .DL(VIDEO_DL),
        .LDPS_N(LDPS_N),
        .FLASH_CLK(FLASH_CLK),
        .VIDEO(VIDEO)
    );
    
    assign we = (cpu == 1'b0) ? (~T65_WE_N) : (~R65C02_WE_N);
    assign A = (cpu == 1'b0) ? (T65_A[15:0]) : R65C02_A;
    assign D_OUT = (cpu == 1'b0) ? T65_DO : R65C02_DO;
    assign T65_DI = (T65_WE_N == 1'b0) ? D_OUT : D_IN;
    assign CPU_EN = (PHASE_ZERO_D == 1'b1 & PHASE_ZERO == 1'b0) ? 1'b1 : 1'b0;
    
    
    always @(posedge CLK_14M)
    begin: cpu_enable
        
        begin
            PHASE_ZERO_D <= PHASE_ZERO;
            CPU_EN_POST <= CPU_EN;
        end
    end
   
    
    //always @(posedge CLK_14M)
	    //if (DEVICE_SELECT[7]) $display("T64_DO: %x",T65_DO);
	    //if (CPU_EN & CPU_WAIT) $display("CPU HALTED");
	  // $display("CPU_EN: %x",CPU_EN);
  
    
    T65 cpu6502(
        .Mode(2'b00),
        .Clk(CLK_14M),
        .Enable(CPU_EN & ~CPU_WAIT),
        .Res_n(~reset),
        
        .Rdy(1'b1),
        .Abort_n(1'b1),
        .SO_n(1'b1),
        
        .IRQ_n(IRQ_n),
        .NMI_n(NMI_n),
        .R_W_n(T65_WE_N),
        .A(T65_A),
        .DI(T65_DI),
        .DO(T65_DO)
    );
    
//`ifdef VERILATOR
	// we don't have a working version of this CHIP yet in verilog
//`else  
    R65C02 cpu65c02(
        .reset((~reset)),
        .clk(CLK_14M),
        .enable(CPU_EN & ~CPU_WAIT),
        .nmi_n(NMI_n),
        .irq_n(IRQ_n),
        .di(D_IN),
        .dout(R65C02_DO),
        .addr(R65C02_A),
        .nwe(R65C02_WE_N)
    );
//`endif 
    
    // Original Apple had asynchronous ROMs.  We use a synchronous ROM
    // that needs its address earlier, hence the odd clock.
   /* 
    spram #(14, 8, "rtl/roms/apple2e.mif") roms(
        .address(rom_addr),
        .clock(CLK_14M),
        .data(1'b0),
        .wren(1'b0),
        .q(rom_out)
    );
    */
   rom #(8,14,"rtl/roms/apple2e.hex") roms (
	   .clock(CLK_14M),
	   .ce(1'b1),
	   .a(rom_addr),
	   .data_out(rom_out)
   );  
endmodule
