//
// Apple II+ toplevel abstract
//
// Copyright (c) 2014 W. Soltys <wsoltys@gmail.com>
//
// This source file is free software: you can redistribute it and/or modify
// it under the terms of the GNU General Public License as published
// by the Free Software Foundation, either version 3 of the License, or
// (at your option) any later version.
//
// This source file is distributed in the hope that it will be useful,
// but WITHOUT ANY WARRANTY; without even the implied warranty of
// MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
// GNU General Public License for more details.
//
// You should have received a copy of the GNU General Public License
// along with this program.  If not, see <http://www.gnu.org/licenses/>.
//

module apple2_top(
    CLK_14M,
    CLK_50M,
    reset_cold,
    reset_warm,
    cpu_type,
    CPU_WAIT,
    ram_we,
    ram_di,
    ram_do,
    ram_addr,
    ram_aux,
    hsync,
    vsync,
    hblank,
    vblank,
    r,
    g,
    b,
    SCREEN_MODE,
    TEXT_COLOR,

    PS2_Key,
    joy,
    joy_an,
    mb_enabled,

    	TRACK1,
	TRACK1_ADDR,
	TRACK1_DI,
	TRACK1_DO,
	TRACK1_WE,
	TRACK1_BUSY,
	TRACK2,
	TRACK2_ADDR,
	TRACK2_DI,
	TRACK2_DO,
	TRACK2_WE,
	TRACK2_BUSY,

	D1_ACTIVE,
	D2_ACTIVE,

	DISK_ACT,

	DISK_READY,


    HDD_SECTOR,
    HDD_READ,
    HDD_WRITE,
    HDD_MOUNTED,
    HDD_PROTECT,
    HDD_RAM_ADDR,
    HDD_RAM_DI,
    HDD_RAM_DO,
    HDD_RAM_WE,
    AUDIO_L,
    AUDIO_R,
    TAPE_IN,
    UART_TXD,
    UART_RXD,
    UART_RTS,
    UART_CTS,
    UART_DTR,
    UART_DSR,
    RTC
);
    input         CLK_14M;
    input         CLK_50M;
    input         reset_cold;
    input         reset_warm;
    input         cpu_type;
    input         CPU_WAIT;
    
    // main RAM
    output        ram_we;
    output [7:0]  ram_di;
    input [15:0]  ram_do;
    output [17:0] ram_addr;
    output        ram_aux;
    
    // video output
    output        hsync;
    output        vsync;
    output        hblank;
    output        vblank;
    output [7:0]  r;
    output [7:0]  g;
    output [7:0]  b;
    input [1:0]   SCREEN_MODE;		// 00: Color, 01: B&W, 10:Green, 11: Amber
    input         TEXT_COLOR;
    
    input [10:0]  PS2_Key;
    input [5:0]   joy;
    input [15:0]  joy_an;
    
    // mocking board
    input         mb_enabled;
   
output [5:0]	TRACK1;
output [12:0] TRACK1_ADDR;
output [7:0] 	TRACK1_DI;
input [7:0]	TRACK1_DO;
output	TRACK1_WE;
input	TRACK1_BUSY;
output [5:0]	TRACK2;
output [12:0] 	TRACK2_ADDR;
output [7:0] 	TRACK2_DI;
input [7:0] 	TRACK2_DO;
output	TRACK2_WE;
input	TRACK2_BUSY;

inout	D1_ACTIVE;
inout	D2_ACTIVE;

output	DISK_ACT;

input[1:0]	DISK_READY;

    
    // HDD control
    output [15:0] HDD_SECTOR;
    output        HDD_READ;
    output        HDD_WRITE;
    input         HDD_MOUNTED;
    input         HDD_PROTECT;
    input [8:0]   HDD_RAM_ADDR;
    input [7:0]   HDD_RAM_DI;
    output [7:0]  HDD_RAM_DO;
    input         HDD_RAM_WE;
    
    output [9:0]  AUDIO_L;
    output [9:0]  AUDIO_R;
    input         TAPE_IN;
    
    output        UART_TXD;
    input         UART_RXD;
    output        UART_RTS;
    input         UART_CTS;
    output        UART_DTR;
    input         UART_DSR;

    input [64:0]  RTC;
    
    // 14.31818 MHz master clock
    // approx. 2 Hz flashing char clock
    // 0 - 6502, 1 - 65C02
    // CPU address
    // RAM address
    // Data to RAM
    // Data from RAM (lo byte: MAIN RAM, hi byte: AUX RAM)
    // Write to MAIN or AUX RAM
    // Data to CPU from peripherals
    // RAM write enable
    // Keyboard data
    // Processor has read key
    // Any key down flag
    // Annunciator outputs
    // GAMEPORT input bits:
    //  7    6    5    4    3   2   1    0
    // pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
    // Pulses high when C07x read
    // Pulses high when C04x read
    // One-bit speaker output
    // 14.31818 MHz master clock
    
    // from the Apple video generator
    // 00: Color, 01: B&W, 10: Green, 11: Amber
    
    // e.g., C600 - C6FF ROM
    // e.g., C0E0 - C0EF I/O locations
    // From 6502
    // To 6502
    // Current track (0-34)
    // Disk 1 motor on
    // Disk 2 motor on
    // Address for track RAM
    // Data to track RAM
    // RAM write enable
    
    wire          CLK_2M;
    reg           CLK_2M_D;
    wire          PHASE_ZERO;
    wire [7:0]    IO_SELECT;
    wire [7:0]    DEVICE_SELECT;
    wire          IO_STROBE;
    wire [15:0]   ADDR;
    wire [7:0]    D;
    wire [7:0]    PD;
    wire [7:0]    DISK_DO;
    wire [7:0]    PSG_DO;
    wire [7:0]    HDD_DO;
    wire [7:0]    CLOCK_DO;
    wire [7:0]    SSC_DO;
    wire          SSC_ROM_EN;
    wire          cpu_we;
    wire          psg_irq_n ;
    wire          psg_nmi_n;
    wire          ssc_irq_n;
    
    wire          we_ram;
    wire          VIDEO;
    wire          HBL;
    wire          VBL;
    wire          COLOR_LINE;
    wire          COLOR_LINE_CONTROL;
    wire          TEXT_MODE = 1'b0;

    wire [7:0]    GAMEPORT;
    
    wire [7:0]    K;
    wire          read_key;
    wire          akd;
    
    reg [22:0]    flash_clk;
    reg           power_on_reset;
    reg           reset;
    
    wire [17:0]   a_ram;
    
    wire [9:0]    psg_audio_l;
    wire [9:0]    psg_audio_r;
    wire [9:0]    audio;
    
    reg           joyx;
    reg           joyy;
    wire          pdl_strobe;
   
    wire          STB; 
    // In the Apple ][, this was a 555 timer
    
    always @(posedge CLK_14M)
    begin: power_on
        
        begin
            reset <= reset_warm | power_on_reset;
            
            if (reset_cold == 1'b1)
            begin
                power_on_reset <= 1'b1;
                flash_clk <= {23{1'b0}};
            end
            else
            begin
                if (flash_clk[22] == 1'b1)
                    power_on_reset <= 1'b0;
                
                flash_clk <= flash_clk + 1;
            end
        end
    end
    
    // Paddle buttons
    // GAMEPORT input bits:
    //  7    6    5    4    3   2   1    0
    // pdl3 pdl2 pdl1 pdl0 pb3 pb2 pb1 casette
    assign GAMEPORT = {2'b00, joyy, joyx, 1'b0, joy[5], joy[4], TAPE_IN};
   
    always @(posedge CLK_14M) begin : P1
    reg [31:0] cx, cy = 0;

    CLK_2M_D <= CLK_2M;
    if(CLK_2M_D == 1'b0 && CLK_2M == 1'b1) begin
      if(cx > 0) begin
        cx = cx - 1;
        joyx <= 1'b1;
      end
      else begin
        joyx <= 1'b0;
      end
      if(cy > 0) begin
        cy = cy - 1;
        joyy <= 1'b1;
      end
      else begin
        joyy <= 1'b0;
      end
      if(pdl_strobe == 1'b1) begin
        cx = 2800 + (22 * ($signed(joy_an[15:8])));
        cy = 2800 + (22 * ($signed(joy_an[7:0])));
        // max 5650
        if(cx < 0) begin
          cx = 0;
        end
        else if(cx >= 5590) begin
          cx = 5650;
        end
        if(cy < 0) begin
          cy = 0;
        end
        else if(cy >= 5590) begin
          cy = 5650;
        end
      end
    end
  end
 
    
    assign COLOR_LINE_CONTROL = (COLOR_LINE | (TEXT_COLOR & ~TEXT_MODE)) &  (~(SCREEN_MODE[1] | SCREEN_MODE[0])); // -- Color or B&W mode
 
    // Simulate power up on cold reset to go to the disk boot routine
    assign ram_we = (reset_cold == 1'b0) ? we_ram : 1'b1;
    assign ram_addr = (reset_cold == 1'b0) ? a_ram : 18'h03F4;//1012; 		// $3F4
    assign ram_di = (reset_cold == 1'b0) ? D : 8'b00000000;
   

    assign PD = //(IO_SELECT[1] == 1'b1 | DEVICE_SELECT[1] == 1'b1) ? CLOCK_DO : 
                (IO_SELECT[7] == 1'b1 | DEVICE_SELECT[7] == 1'b1) ? HDD_DO : 
                (IO_SELECT[6] == 1'b1 | DEVICE_SELECT[6] == 1'b1) ? DISK_DO : 
                //(IO_SELECT[2] == 1'b1 | DEVICE_SELECT[2] == 1'b1 | SSC_ROM_EN == 1'b1) ? SSC_DO : 		// AJS turn on port
                DISK_DO;
    
    
    apple2 core(
        .CLK_14M(CLK_14M),
        .CLK_2M(CLK_2M),
        .CPU_WAIT(CPU_WAIT),
        .PHASE_ZERO(PHASE_ZERO),
        .FLASH_CLK(flash_clk[22]),
        .reset(reset),
        .cpu(cpu_type),
        .ADDR(ADDR),
        .ram_addr(a_ram),
        .D(D),
        .ram_do(ram_do),
        .aux(ram_aux),
        .PD(PD),
        .CPU_WE(cpu_we),
        .IRQ_n(1/*psg_irq_n & ssc_irq_n*/),
        .NMI_n(1/*psg_nmi_n*/),
        .ram_we(we_ram),
        .VIDEO(VIDEO),
        .COLOR_LINE(COLOR_LINE),
	//.TEXT_MODE(TEXT_MODE),
        .HBL(HBL),
        .VBL(VBL),
        .K(K),
        .READ_KEY(read_key),
        .AKD(akd),
        .AN(),
        .GAMEPORT(GAMEPORT),
        .PDL_STROBE(pdl_strobe),
	.STB(STB),
        .IO_SELECT(IO_SELECT),
        .DEVICE_SELECT(DEVICE_SELECT),
        .IO_STROBE(IO_STROBE),
        .speaker(audio[7])
    );
    
    
    vga_controller tv(
        .CLK_14M(CLK_14M),
        .VIDEO(VIDEO),
        .COLOR_LINE(COLOR_LINE_CONTROL),
        .SCREEN_MODE(SCREEN_MODE),
        .HBL(HBL),
        .VBL(VBL),
        .VGA_HS(hsync),
        .VGA_VS(vsync),
        .VGA_HBL(hblank),
        .VGA_VBL(vblank),
        .VGA_R(r),
        .VGA_G(g),
        .VGA_B(b)
    );
    
    
    keyboard keyboard(
        .PS2_Key(PS2_Key),
        .CLK_14M(CLK_14M),
        .reset(reset),
        .reads(read_key),
        .K(K),
        .akd(akd)
    );
   
    assign DISK_ACT = ~(D1_ACTIVE | D2_ACTIVE);

  disk_ii disk_ii (
        .CLK_14M(CLK_14M),
        .CLK_2M(CLK_2M),
        .PHASE_ZERO(PHASE_ZERO),
        .IO_SELECT(IO_SELECT[6]),
        .DEVICE_SELECT(DEVICE_SELECT[6]),
        .RESET(reset),
        .DISK_READY(DISK_READY),
        .A(ADDR),
        .D_IN(D),
        .D_OUT(DISK_DO),
    .D1_ACTIVE(D1_ACTIVE),
    .D2_ACTIVE(D2_ACTIVE),
    //-- track buffer interface for disk 1  -- TODO
    .TRACK1(TRACK1),
    .TRACK1_ADDR(TRACK1_ADDR),
    .TRACK1_DO(TRACK1_DO),
    .TRACK1_DI(TRACK1_DI),
    .TRACK1_WE(TRACK1_WE),
    .TRACK1_BUSY(TRACK1_BUSY),
    //-- track buffer interface for disk 2  -- TODO
    .TRACK2(TRACK2),
    .TRACK2_ADDR(TRACK2_ADDR),
    .TRACK2_DO(TRACK2_DO),
    .TRACK2_DI(TRACK2_DI),
    .TRACK2_WE(TRACK2_WE),
    .TRACK2_BUSY(TRACK2_BUSY)
    );

    
    
`ifdef NO
    hdd hdd(
        .CLK_14M(CLK_14M),
        .PHASE_ZERO(PHASE_ZERO),
        .IO_SELECT(IO_SELECT[7]),
        .DEVICE_SELECT(DEVICE_SELECT[7]),
        .RESET(reset),
        .A(ADDR),
        .RD(~cpu_we),
        .D_IN(D),
        .D_OUT(HDD_DO),
        .sector(HDD_SECTOR),
        .hdd_read(HDD_READ),
        .hdd_write(HDD_WRITE),
        .hdd_mounted(HDD_MOUNTED),
        .hdd_protect(HDD_PROTECT),
        .ram_addr(HDD_RAM_ADDR),
        .ram_di(HDD_RAM_DI),
        .ram_do(HDD_RAM_DO),
        .ram_we(HDD_RAM_WE)
    );
   
 
    MOCKINGBOARD mb(
        .CLK_14M(CLK_14M),
        .PHASE_ZERO(PHASE_ZERO),
        .I_RESET_L(~reset),
        .I_ENA_H(mb_enabled),
        
        .I_ADDR(ADDR[7:0]),
        .I_DATA(D),
        .O_DATA(PSG_DO),
        .I_RW_L(~cpu_we),
        .I_IOSEL_L(~IO_SELECT[4]),
        .O_IRQ_L(psg_irq_n),
        .O_NMI_L(psg_nmi_n),
        .O_AUDIO_L(psg_audio_l),
        .O_AUDIO_R(psg_audio_r)
    );
   
  
 
      superserial ssc(
        .CLK_50M(CLK_50M), 
        .CLK_14M(CLK_14M), 
        .CLK_2M(CLK_2M), 
        .PH_2(PHASE_ZERO), 
        .IO_SELECT_N(~IO_SELECT[2]),
        .DEVICE_SELECT_N(~DEVICE_SELECT[2]),
        .IO_STROBE_N(~IO_STROBE), 
        .ADDRESS(ADDR), 
        .RW_N(~cpu_we), 
        .RESET(reset), 
        .DATA_IN(D), 
        .DATA_OUT(SSC_DO), 
        .ROM_EN(SSC_ROM_EN), 
        .UART_CTS(UART_CTS), 
        .UART_RTS(UART_RTS), 
        .UART_RXD(UART_RXD), 
        .UART_TXD(UART_TXD), 
        .UART_DTR(UART_DTR), 
        .UART_DSR(UART_DSR), 
        .IRQ_N(ssc_irq_n)
     );
      
      clock_card clock(
        .CLK_14M(CLK_14M), 
        .CLK_2M(CLK_2M), 
        .PH_2(PHASE_ZERO), 
        .IO_SELECT_N(~IO_SELECT[1]),
        .DEVICE_SELECT_N(~DEVICE_SELECT[1]),
        .IO_STROBE_N(~IO_STROBE), 
        .ADDRESS(ADDR), 
        .RW_N(~cpu_we), 
        .RESET(reset), 
        .DATA_IN(D), 
        .DATA_OUT(CLOCK_DO), 
        .ROM_EN(CLOCK_ROM_EN), 
        .IRQ_N(),
	.RTC(RTC)
     );
      
     `endif

    assign audio[6:0] = 7'b0;
    assign audio[9:8] = 2'b0;
    assign AUDIO_R = (psg_audio_r + audio);
    assign AUDIO_L = (psg_audio_l + audio);
    
endmodule
