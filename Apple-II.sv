//============================================================================
//  Apple II+
//
//  Port to MiSTer
//  Copyright (C) 2017-2019 Sorgelig
//
//  This program is free software; you can redistribute it and/or modify it
//  under the terms of the GNU General Public License as published by the Free
//  Software Foundation; either version 2 of the License, or (at your option)
//  any later version.
//
//  This program is distributed in the hope that it will be useful, but WITHOUT
//  ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or
//  FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public License for
//  more details.
//
//  You should have received a copy of the GNU General Public License along
//  with this program; if not, write to the Free Software Foundation, Inc.,
//  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
//============================================================================

module emu
(
	//Master input clock
	input         CLK_50M,

	//Async reset from top-level module.
	//Can be used as initial reset.
	input         RESET,

	//Must be passed to hps_io module
	inout  [45:0] HPS_BUS,

	//Base video clock. Usually equals to CLK_SYS.
	output        CLK_VIDEO,

	//Multiple resolutions are supported using different CE_PIXEL rates.
	//Must be based on CLK_VIDEO
	output        CE_PIXEL,

	//Video aspect ratio for HDMI. Most retro systems have ratio 4:3.
	//if VIDEO_ARX[12] or VIDEO_ARY[12] is set then [11:0] contains scaled size instead of aspect ratio.
	output [12:0] VIDEO_ARX,
	output [12:0] VIDEO_ARY,

	output  [7:0] VGA_R,
	output  [7:0] VGA_G,
	output  [7:0] VGA_B,
	output        VGA_HS,
	output        VGA_VS,
	output        VGA_DE,    // = ~(VBlank | HBlank)
	output        VGA_F1,
	output [1:0]  VGA_SL,
	output        VGA_SCALER, // Force VGA scaler

	input  [11:0] HDMI_WIDTH,
	input  [11:0] HDMI_HEIGHT,
	output        HDMI_FREEZE,

`ifdef MISTER_FB
	// Use framebuffer in DDRAM (USE_FB=1 in qsf)
	// FB_FORMAT:
	//    [2:0] : 011=8bpp(palette) 100=16bpp 101=24bpp 110=32bpp
	//    [3]   : 0=16bits 565 1=16bits 1555
	//    [4]   : 0=RGB  1=BGR (for 16/24/32 modes)
	//
	// FB_STRIDE either 0 (rounded to 256 bytes) or multiple of pixel size (in bytes)
	output        FB_EN,
	output  [4:0] FB_FORMAT,
	output [11:0] FB_WIDTH,
	output [11:0] FB_HEIGHT,
	output [31:0] FB_BASE,
	output [13:0] FB_STRIDE,
	input         FB_VBL,
	input         FB_LL,
	output        FB_FORCE_BLANK,

`ifdef MISTER_FB_PALETTE
	// Palette control for 8bit modes.
	// Ignored for other video modes.
	output        FB_PAL_CLK,
	output  [7:0] FB_PAL_ADDR,
	output [23:0] FB_PAL_DOUT,
	input  [23:0] FB_PAL_DIN,
	output        FB_PAL_WR,
`endif
`endif

	output        LED_USER,  // 1 - ON, 0 - OFF.

	// b[1]: 0 - LED status is system status OR'd with b[0]
	//       1 - LED status is controled solely by b[0]
	// hint: supply 2'b00 to let the system control the LED.
	output  [1:0] LED_POWER,
	output  [1:0] LED_DISK,

	// I/O board button press simulation (active high)
	// b[1]: user button
	// b[0]: osd button
	output  [1:0] BUTTONS,

	input         CLK_AUDIO, // 24.576 MHz
	output [15:0] AUDIO_L,
	output [15:0] AUDIO_R,
	output        AUDIO_S,   // 1 - signed audio samples, 0 - unsigned
	output  [1:0] AUDIO_MIX, // 0 - no mix, 1 - 25%, 2 - 50%, 3 - 100% (mono)

	//ADC
	inout   [3:0] ADC_BUS,

	//SD-SPI
	output        SD_SCK,
	output        SD_MOSI,
	input         SD_MISO,
	output        SD_CS,
	input         SD_CD,

	//High latency DDR3 RAM interface
	//Use for non-critical time purposes
	output        DDRAM_CLK,
	input         DDRAM_BUSY,
	output  [7:0] DDRAM_BURSTCNT,
	output [28:0] DDRAM_ADDR,
	input  [63:0] DDRAM_DOUT,
	input         DDRAM_DOUT_READY,
	output        DDRAM_RD,
	output [63:0] DDRAM_DIN,
	output  [7:0] DDRAM_BE,
	output        DDRAM_WE,

	//SDRAM interface with lower latency
	output        SDRAM_CLK,
	output        SDRAM_CKE,
	output [12:0] SDRAM_A,
	output  [1:0] SDRAM_BA,
	inout  [15:0] SDRAM_DQ,
	output        SDRAM_DQML,
	output        SDRAM_DQMH,
	output        SDRAM_nCS,
	output        SDRAM_nCAS,
	output        SDRAM_nRAS,
	output        SDRAM_nWE,

`ifdef MISTER_DUAL_SDRAM
	//Secondary SDRAM
	//Set all output SDRAM_* signals to Z ASAP if SDRAM2_EN is 0
	input         SDRAM2_EN,
	output        SDRAM2_CLK,
	output [12:0] SDRAM2_A,
	output  [1:0] SDRAM2_BA,
	inout  [15:0] SDRAM2_DQ,
	output        SDRAM2_nCS,
	output        SDRAM2_nCAS,
	output        SDRAM2_nRAS,
	output        SDRAM2_nWE,
`endif

	input         UART_CTS,
	output        UART_RTS,
	input         UART_RXD,
	output        UART_TXD,
	output        UART_DTR,
	input         UART_DSR,

	// Open-drain User port.
	// 0 - D+/RX
	// 1 - D-/TX
	// 2..6 - USR2..USR6
	// Set USER_OUT to 1 to read from USER_IN.
	input   [6:0] USER_IN,
	output  [6:0] USER_OUT,

	input         OSD_STATUS
);

assign USER_OUT = '1;
//assign {UART_RTS, UART_TXD, UART_DTR} = 0;
assign {SD_SCK, SD_MOSI, SD_CS} = 'Z;
//assign {SDRAM_DQ, SDRAM_A, SDRAM_BA, SDRAM_CLK, SDRAM_CKE, SDRAM_DQML, SDRAM_DQMH, SDRAM_nWE, SDRAM_nCAS, SDRAM_nRAS, SDRAM_nCS} = 'Z;
assign {DDRAM_CLK, DDRAM_BURSTCNT, DDRAM_ADDR, DDRAM_DIN, DDRAM_BE, DDRAM_RD, DDRAM_WE} = 0;
 
assign LED_USER  = led;
assign LED_DISK  = 0;
assign LED_POWER = 0;
assign BUTTONS   = 0;
assign VGA_SCALER= 0;
assign VGA_F1    = 0;
assign HDMI_FREEZE = 0;

wire [1:0] ar = status[13:12];
video_freak video_freak
(
	.*,
	.VGA_DE_IN(VGA_DE),
	.VGA_DE(),
	.ARX((!ar) ? 12'd4 : (ar - 1'd1)),
	.ARY((!ar) ? 12'd3 : 12'd0),
	.CROP_SIZE(0),
	.CROP_OFF(0),
	.SCALE(status[15:14])
);

`include "build_id.v" 
parameter CONF_STR = {
	"Apple-II;UART19200:9600:4800:2400:1200;",
	"-;",
	//"F1,NIB,Load Disk IOCTL;",
	"S0,NIBDSKDO PO ;",
	"S1,HDV;",
	"-;",
	"OCD,Aspect ratio,Original,Full Screen,[ARC1],[ARC2];",
	"O23,Display,Color,B&W,Green,Amber;",
	"O9B,Scandoubler Fx,None,HQ2x,CRT 25%,CRT 50%,CRT 75%;", 
	"OEF,Scale,Normal,V-Integer,Narrower HV-Integer,Wider HV-Integer;",
	"OG,Pixel Clock,Double,Normal;",
	"-;",
	"O5,CPU,6502,65C02;",
	"O4,Mocking board,Yes,No;",
	"O78,Stereo mix,none,25%,50%,100%;",
	"-;",
	"O6,Analog X/Y,Normal,Swapped;",
	"OHI,Paddle as analog,No,X,Y;",
	"-;",
	"R0,Cold Reset;",
	"JA,Fire 1,Fire 2;",
	"V,v",`BUILD_DATE
};

/////////////////  CLOCKS  ////////////////////////

wire clk_sys;
wire clock_locked;

pll pll
(
	.refclk(CLK_50M),
	.rst(0),
	.outclk_0(CLK_VIDEO),
	.outclk_1(clk_sys),
	.locked(clock_locked)
);

/////////////////  HPS  ///////////////////////////

wire [31:0] status;
wire  [1:0] buttons;
wire        forced_scandoubler;
wire [21:0] gamma_bus;

wire [15:0] joystick_0;
wire [15:0] joystick_a0;
wire  [7:0] paddle_0;

wire [10:0] ps2_key;

wire [31:0] sd_lba[2];
reg   [1:0] sd_rd;
reg   [1:0] sd_wr;
wire  [1:0] sd_ack;
wire  [8:0] sd_buff_addr;
wire  [7:0] sd_buff_dout;
wire  [7:0] sd_buff_din[2];
wire        sd_buff_wr;
wire  [1:0] img_mounted;
wire        img_readonly;

wire [63:0] img_size;

wire        ioctl_download;
wire [24:0] ioctl_addr;
wire [7:0]  ioctl_dout;
wire        ioctl_wr;
wire [7:0]  ioctl_index;
wire        ioctl_wait;

wire [64:0] RTC;

hps_io #(.CONF_STR(CONF_STR), .VDNUM(2)) hps_io
(
	.clk_sys(clk_sys),
	.HPS_BUS(HPS_BUS),

	.buttons(buttons),
	.status(status),
	.forced_scandoubler(forced_scandoubler),
	.gamma_bus(gamma_bus),

	.sd_lba(sd_lba),
	.sd_rd(sd_rd),
	.sd_wr(sd_wr),
	.sd_ack(sd_ack),
	.sd_buff_addr(sd_buff_addr),
	.sd_buff_dout(sd_buff_dout),
	.sd_buff_din(sd_buff_din),
	.sd_buff_wr(sd_buff_wr),
	.img_mounted(img_mounted),
	.img_readonly(img_readonly),
	.img_size(img_size),

//	.ioctl_wait(0),
	
	
	.ioctl_addr(ioctl_addr),
	.ioctl_dout(ioctl_dout),
	.ioctl_wr(ioctl_wr),
	.ioctl_download(ioctl_download),
	.ioctl_index(ioctl_index),
	.ioctl_wait(ioctl_wait),

	.RTC(RTC),	

	.ps2_key(ps2_key),

	.joystick_0(joystick_0),
	.joystick_l_analog_0(joystick_a0),
	.paddle_0(paddle_0)
);

///////////////////////////////////////////////////

wire  [7:0] pdl  = {~paddle_0[7], paddle_0[6:0]};
wire [15:0] joys = status[6] ? joystick_a0 : {joystick_a0[7:0],joystick_a0[15:8]};
wire [15:0] joya = {status[17] ? pdl : joys[15:8], status[18] ? pdl : joys[7:0]};
wire  [5:0] joyd = joystick_0[5:0] & {2'b11, {2{~|joys[7:0]}}, {2{~|joys[15:8]}}};

wire [9:0] audio_l, audio_r;

assign AUDIO_L = {1'b0, audio_l, 5'd0};
assign AUDIO_R = {1'b0, audio_r, 5'd0};
assign AUDIO_S = 0;
assign AUDIO_MIX = status[8:7];

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg [2:0] div = 0;
	
	div <= div + 1'd1;
	ce_pix <= status[16] ? &div : &div[1:0];
end

wire led;
wire hbl,vbl;
wire fd_write;
wire	fd_write_disk;
wire	fd_read_disk;
wire [13:0] fd_track_addr;
wire [7:0] fd_data_in;
wire [7:0] fd_data_do;
apple2_top apple2_top
(
	.CLK_14M(clk_sys),
	.CLK_50M(CLK_50M),
	.CPU_WAIT(cpu_wait_hdd | cpu_wait_fdd),
	.cpu_type(status[5]),

	.reset_cold(RESET | status[0]),
	.reset_warm(buttons[1]),

	.hblank(HBlank),
	.vblank(VBlank),
	.hsync(HSync),
	.vsync(VSync),
	.r(R),
	.g(G),
	.b(B),
	.SCREEN_MODE(status[3:2]),

	.AUDIO_L(audio_l),
	.AUDIO_R(audio_r),
	.TAPE_IN(tape_adc_act & tape_adc),

	.PS2_Key(ps2_key),

	.joy(joyd),
	.joy_an(joya),

	.mb_enabled(~status[4]),

	.TRACK(track),
	.DISK_RAM_ADDR({track_sec, sd_buff_addr}),
	.DISK_TRACK_ADDR(),
	.DISK_RAM_DI(sd_buff_dout),
	.DISK_RAM_DO(/*sd_buff_din[0]*/),
	.DISK_RAM_WE(sd_buff_wr & sd_ack[0]),



	.DISK_FD_READ_DISK(fd_read_disk),
	.DISK_FD_WRITE_DISK(fd_write_disk),
	.DISK_FD_TRACK_ADDR(fd_track_addr),
	.DISK_FD_DATA_IN(fd_data_in),
	.DISK_FD_DATA_OUT(fd_data_do),

	
	.HDD_SECTOR(sd_lba[1]),
	.HDD_READ(hdd_read),
	.HDD_WRITE(hdd_write),
	.HDD_MOUNTED(hdd_mounted),
	.HDD_PROTECT(hdd_protect),
	.HDD_RAM_ADDR(sd_buff_addr),
	.HDD_RAM_DI(sd_buff_dout),
	.HDD_RAM_DO(sd_buff_din[1]),
	.HDD_RAM_WE(sd_buff_wr & sd_ack[1]),

	.ram_addr(ram_addr),
	.ram_do(ram_dout),
	.ram_di(ram_din),
	.ram_we(ram_we),
	.ram_aux(ram_aux),

	.DISK_ACT(led),

	.UART_TXD(UART_TXD),
	.UART_RXD(UART_RXD),
	.UART_RTS(UART_RTS),
	.UART_CTS(UART_CTS),
	.UART_DTR(UART_DTR),
	.UART_DSR(UART_DSR),

	.RTC(RTC)


);

wire [2:0] scale = status[11:9];
wire [2:0] sl = scale ? scale - 1'd1 : 3'd0;
wire       scandoubler = (scale || forced_scandoubler);

assign VGA_SL = sl[1:0];

wire [7:0] R,G,B;
wire HSync, VSync, HBlank, VBlank;

video_mixer #(.LINE_LENGTH(580), .GAMMA(1)) video_mixer
(
	.*,
	.hq2x(scale==1),
	.freeze_sync()
);

wire [17:0] ram_addr;
reg  [15:0] ram_dout;
wire  [7:0]	ram_din;
wire        ram_we;
wire        ram_aux;

reg [7:0] ram0[196608];
always @(posedge clk_sys) begin
	if(ram_we & ~ram_aux) begin
		ram0[ram_addr] <= ram_din;
		ram_dout[7:0]  <= ram_din;
	end else begin
		ram_dout[7:0]  <= ram0[ram_addr];
	end
end

reg [7:0] ram1[65536];
always @(posedge clk_sys) begin
	if(ram_we & ram_aux) begin
		ram1[ram_addr[15:0]] <= ram_din;
		ram_dout[15:8] <= ram_din;
	end else begin
		ram_dout[15:8] <= ram1[ram_addr[15:0]];
	end
end

wire dd_reset = RESET | status[0] | buttons[1];

reg  hdd_mounted = 0;
wire hdd_read;
wire hdd_write;
reg  hdd_protect;
reg  cpu_wait_hdd = 0;

always @(posedge clk_sys) begin
	reg state = 0;
	reg old_ack = 0;
	reg hdd_read_pending = 0;
	reg hdd_write_pending = 0;

	old_ack <= sd_ack[1];
	hdd_read_pending <= hdd_read_pending | hdd_read;
	hdd_write_pending <= hdd_write_pending | hdd_write;

	if (img_mounted[1]) begin
		hdd_mounted <= img_size != 0;
		hdd_protect <= img_readonly;
	end

	if(dd_reset) begin
		state <= 0;
		cpu_wait_hdd <= 0;
		hdd_read_pending <= 0;
		hdd_write_pending <= 0;
		sd_rd[1] <= 0;
		sd_wr[1] <= 0;
	end
	else if(!state) begin
		if (hdd_read_pending | hdd_write_pending) begin
			state <= 1;
			sd_rd[1] <= hdd_read_pending;
			sd_wr[1] <= hdd_write_pending;
			cpu_wait_hdd <= 1;
		end
	end
	else begin
		if (~old_ack & sd_ack[1]) begin
			hdd_read_pending <= 0;
			hdd_write_pending <= 0;
			sd_rd[1] <= 0;
			sd_wr[1] <= 0;
		end
		else if(old_ack & ~sd_ack[1]) begin
			state <= 0;
			cpu_wait_hdd <= 0;
		end
	end
end







// [12:9] -- this is the track number


`ifdef OLDCODE
assign      sd_lba[0] = lba_fdd;
wire  [5:0] track;
reg   [3:0] track_sec;
reg         cpu_wait_fdd = 0;
reg  [31:0] lba_fdd;
reg       fd_write_pending = 0;

always @(posedge clk_sys) begin
	reg       state = 0;
	reg       wr_state=0;
	reg [5:0] cur_track;
	reg       fdd_mounted = 0;
	reg       old_ack = 0;
	
	old_ack <= sd_ack[0];
	fdd_mounted <= fdd_mounted | img_mounted[0];
	sd_wr[0] <= 0;

	if(dd_reset) begin
		state <= 0;
		cpu_wait_fdd <= 0;
		sd_rd[0] <= 0;
		fd_write_pending<=0;
	end
	else if(!state) begin
		if((cur_track != track) || (fdd_mounted && ~img_mounted[0])) begin
			cur_track <= track;
			fdd_mounted <= 0;
			if(img_size) begin
				track_sec <= 0;
				lba_fdd <= 13 * track;
				state <= 1;
				sd_rd[0] <= 1;
				cpu_wait_fdd <= 1;
			end
		end
	end
	else begin
		if(~old_ack & sd_ack[0]) begin
			if(track_sec >= 12) sd_rd[0] <= 0;
			lba_fdd <= lba_fdd + 1'd1;
		end else if(old_ack & ~sd_ack[0]) begin
			track_sec <= track_sec + 1'd1;
			if(~sd_rd[0]) state <= 0;
			cpu_wait_fdd <= 0;
		end
	end
	
	// write one track .. 
/*
	fd_write_pending <= fd_write_pending | fd_write;
	
	if (dd_reset) begin	
		wr_state<=0;
		fd_write_pending <= 0;
		sd_wr[0] <= 0;
	end
	else if(!wr_state) begin
		if (fd_write_pending) begin
			wr_state <= 1;
			sd_wr[0] <= fd_write_pending;
			cpu_wait_fdd <= 1;
			lba_fdd<= (13 * track) + fd_track_addr[12:9];
			track_sec <= fd_track_addr[12:9];

		end
	end
	else begin
		if (~old_ack & sd_ack[0]) begin
			fd_write_pending <= 0;
			sd_wr[0] <= 0;
		end
		else if(old_ack & ~sd_ack[0]) begin
			wr_state <= 0;
			cpu_wait_fdd <= 0;
		end
	end
*/
end

`endif


assign      sd_lba[0] = lba_fdd;
wire  [5:0] track;
reg   [3:0] track_sec;
reg         cpu_wait_fdd = 0;
reg  [31:0] lba_fdd;
reg       fd_write_pending = 0;

reg       fdd_mounted ;

// when we write to the disk, we need to mark it dirty
reg floppy_track_dirty;


always @(posedge clk_sys) begin
        reg       wr_state;
        reg [5:0] cur_track;
        reg       old_ack ;
        reg       [1:0] state ;

        old_ack <= sd_ack[0];
        fdd_mounted <= fdd_mounted | img_mounted[0];
        //sd_wr[0] <= 0;

        if (fd_write_disk)
        begin
                floppy_track_dirty<=1;
                // reset timer
        end

        if(dd_reset) begin
                state <= 0;
                cpu_wait_fdd <= 0;
                sd_rd[0] <= 0;
                fd_write_pending<=0;
                floppy_track_dirty<=0;
        end
        else case(state)
                2'b00:  // looking for a track change or a timeout
                if((cur_track != track) || (fdd_mounted && ~img_mounted[0])) begin


                        fdd_mounted <= 0;
                        if(img_size) begin
                                if (floppy_track_dirty)
                                begin
                                        $display("THIS TRACK HAS CHANGES cur_track %x track %x",cur_track,track);
                                        track_sec <= 0;
                                        floppy_track_dirty<=0;
                                        lba_fdd <= 13 * cur_track;
                                        state <= 2'b01;
                                        sd_wr[0] <= 1;
                                        cpu_wait_fdd <= 1;
                                end
                                else
                                        state<=2'b10;
                        end
                end
                2'b01:  // write data
                begin
                        if(~old_ack & sd_ack[0]) begin
                                if(track_sec >= 12) sd_wr[0] <= 0;
                                lba_fdd <= lba_fdd + 1'd1;
                        end else if(old_ack & ~sd_ack[0]) begin
                                track_sec <= track_sec + 1'd1;
                                if(~sd_wr[0]) state <= 2'b10;
                        end
                end
                2'b10:  // start read
                begin
                        cur_track <= track;
                        track_sec <= 0;
                        lba_fdd <= 13 * track;
                        state <= 2'b11;
                        sd_rd[0] <= 1;
                        cpu_wait_fdd <= 1;
                end
                2'b11:  // read data
                begin
                        if(~old_ack & sd_ack[0]) begin
                                if(track_sec >= 12) sd_rd[0] <= 0;
                                lba_fdd <= lba_fdd + 1'd1;
                        end else if(old_ack & ~sd_ack[0]) begin
                                track_sec <= track_sec + 1'd1;
                                if(~sd_rd[0]) state <= 2'b0;
                                cpu_wait_fdd <= 0;
                        end
                end
        endcase
end

 dpram #(14,8) floppy_dpram
(
	.clock_a(clk_sys),
	.address_a({track_sec, sd_buff_addr}),
	.wren_a(sd_buff_wr & sd_ack[0]),
	.data_a(sd_buff_dout),
	.q_a(sd_buff_din[0]),
	
	.clock_b(clk_sys),
	.address_b(fd_track_addr),
	.wren_b(fd_write_disk),
	.data_b(fd_data_do),
	.q_b(fd_data_in)
);


wire fd_busy;
wire sd_busy;
reg ch1_rd;
always @(posedge CLK_VIDEO) begin
	reg state;
	ch1_rd<=0;
	
	if (~fd_busy & fd_read_disk)
		ch1_rd <=1;
end
/*
sdram sdram
(
	.*,

	// system interface
	.clk        ( CLK_VIDEO         ),
	.init       ( !clock_locked   ),

	// cpu/chipset interface
	.ch0_addr   ({track_sec, sd_buff_addr} ),
	.ch0_wr     (sd_buff_wr & sd_ack[0]),
	.ch0_din    (sd_buff_dout),
	.ch0_rd     (),
	.ch0_dout   (),
	.ch0_busy   (ch0_busy),

	.ch1_addr   ( fd_track_addr ),
	.ch1_wr     ( fd_write_disk ),
	.ch1_din    (  fd_data_do),
	.ch1_rd     ( ch1_rd ),
	.ch1_dout   ( fd_data_in ),
	.ch1_busy   ( fd_busy ),

	// reserved for backup ram save/load
	.ch2_addr   ( ),
	.ch2_wr     (  ),
	.ch2_din    (  ),
	.ch2_rd     (  ),
	.ch2_dout   (  ),
	.ch2_busy   (  )
);
*/

	

wire tape_adc, tape_adc_act;
ltc2308_tape ltc2308_tape
(
	.clk(CLK_50M),
	.ADC_BUS(ADC_BUS),
	.dout(tape_adc),
	.active(tape_adc_act)
);


endmodule
