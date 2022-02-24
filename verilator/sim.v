`timescale 1ns / 1ps
/*============================================================================
	Aznable (custom 8-bit computer system) - Verilator emu module

	Author: Jim Gregory - https://github.com/JimmyStones/
	Version: 1.1
	Date: 2021-10-17

	This program is free software; you can redistribute it and/or modify it
	under the terms of the GNU General Public License as published by the Free
	Software Foundation; either version 3 of the License, or (at your option)
	any later version.

	This program is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License along
	with this program. If not, see <http://www.gnu.org/licenses/>.
===========================================================================*/

module emu (

	input clk_sys,
	input reset,
	input soft_reset,
	input menu,
	
	input [31:0] joystick_0,
	input [31:0] joystick_1,
	input [31:0] joystick_2,
	input [31:0] joystick_3,
	input [31:0] joystick_4,
	input [31:0] joystick_5,
	
	input [15:0] joystick_l_analog_0,
	input [15:0] joystick_l_analog_1,
	input [15:0] joystick_l_analog_2,
	input [15:0] joystick_l_analog_3,
	input [15:0] joystick_l_analog_4,
	input [15:0] joystick_l_analog_5,
	
	input [15:0] joystick_r_analog_0,
	input [15:0] joystick_r_analog_1,
	input [15:0] joystick_r_analog_2,
	input [15:0] joystick_r_analog_3,
	input [15:0] joystick_r_analog_4,
	input [15:0] joystick_r_analog_5,

	input [7:0] paddle_0,
	input [7:0] paddle_1,
	input [7:0] paddle_2,
	input [7:0] paddle_3,
	input [7:0] paddle_4,
	input [7:0] paddle_5,

	input [8:0] spinner_0,
	input [8:0] spinner_1,
	input [8:0] spinner_2,
	input [8:0] spinner_3,
	input [8:0] spinner_4,
	input [8:0] spinner_5,

	// ps2 alternative interface.
	// [8] - extended, [9] - pressed, [10] - toggles with every press/release
	input [10:0] ps2_key,

	// [24] - toggles with every event
	input [24:0] ps2_mouse,
	input [15:0] ps2_mouse_ext, // 15:8 - reserved(additional buttons), 7:0 - wheel movements

	// [31:0] - seconds since 1970-01-01 00:00:00, [32] - toggle with every change
	input [32:0] timestamp,

	output [7:0] VGA_R,
	output [7:0] VGA_G,
	output [7:0] VGA_B,
	
	output VGA_HS,
	output VGA_VS,
	output VGA_HB,
	output VGA_VB,

	output CE_PIXEL,
	
	output	[15:0]	AUDIO_L,
	output	[15:0]	AUDIO_R,
	
	input			ioctl_download,
	input			ioctl_wr,
	input [24:0]		ioctl_addr,
	input [7:0]		ioctl_dout,
	input [7:0]		ioctl_index,
	output reg		ioctl_wait=1'b0,

	output [31:0] 		sd_lba[2],
	output [1:0] 		sd_rd,
	output [1:0] 		sd_wr,
	input [1:0] 		sd_ack,
	input [8:0] 		sd_buff_addr,
	input [7:0] 		sd_buff_dout,
	output [7:0] 		sd_buff_din[2],
	input 			sd_buff_wr,
	input [1:0] 		img_mounted,
	input 			img_readonly,

	input [63:0] 		img_size



);
wire [15:0] joystick_a0 =  joystick_l_analog_0;
/*
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
*/
wire UART_CTS;
wire UART_RTS;
wire UART_RXD;
wire UART_TXD;
wire UART_DTR;
wire UART_DSR;

wire CLK_VIDEO = clk_sys;

wire  [7:0] pdl  = {~paddle_0[7], paddle_0[6:0]};
wire [15:0] joys = joystick_a0;
wire [15:0] joya = {joys[15:8], joys[7:0]};
wire  [5:0] joyd = joystick_0[5:0] & {2'b11, {2{~|joys[7:0]}}, {2{~|joys[15:8]}}};

assign AUDIO_L = {audio_l,6'b0};
assign AUDIO_R = {audio_r,6'b0};
wire [9:0] audio_l, audio_r;

reg ce_pix;
always @(posedge CLK_VIDEO) begin
	reg div ;
	
	div <= ~div;
	ce_pix <=  &div ;
end
assign CE_PIXEL=ce_pix;
wire led;
wire hbl,vbl;
wire fd_write;
wire	fd_write_disk;
wire	fd_read_disk;
wire [13:0] fd_track_addr;
wire [7:0] fd_data_in;
wire [7:0] fd_data_do;
always @(posedge clk_sys) begin
	//if (soft_reset) $display("soft_reset %x",soft_reset);
end
apple2_top apple2_top
(
	.CLK_14M(clk_sys),
	.CLK_50M(CLK_50M),
	.CPU_WAIT(cpu_wait_hdd | cpu_wait_fdd),
	.cpu_type(1'b0), // 0 6502, 1 65C02

	.reset_cold(reset),
	.reset_warm(soft_reset),

	.hblank(VGA_HB),
	.vblank(VGA_VB),
	.hsync(VGA_HS),
	.vsync(VGA_VS),
	.r(VGA_R),
	.g(VGA_G),
	.b(VGA_B),
	.SCREEN_MODE(2'b00),
	.TEXT_COLOR(1'b0),

	.AUDIO_L(audio_l),
	.AUDIO_R(audio_r),
	.TAPE_IN(tape_adc_act & tape_adc),

	.PS2_Key(ps2_key),

	.joy(joyd),
	.joy_an(joya),

	.mb_enabled(1'b0),

	.TRACK(track),
	.DISK_RAM_ADDR({track_sec, sd_buff_addr}),
	.DISK_TRACK_ADDR(),
	.DISK_RAM_DI(sd_buff_dout),
	.DISK_RAM_DO(sd_buff_din[0]),
	.DISK_RAM_WE(sd_buff_wr & sd_ack[0]),



	.DISK_FD_READ_DISK(fd_read_disk),
	.DISK_FD_WRITE_DISK(fd_write_disk),
	.DISK_FD_TRACK_ADDR(fd_track_addr),
	.DISK_FD_DATA_IN(fd_data_in),
	.DISK_FD_DATA_OUT(fd_data_do),

    	.FLOPPY_ADDRESS(FLOPPY_ADDRESS),
        .FLOPPY_DATA_IN(FLOPPY_DATA_IN),
	
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
	.UART_DSR(UART_DSR)


);


wire [7:0] R,G,B;
wire HSync, VSync, HBlank, VBlank;


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

reg  hdd_mounted = 0;
wire hdd_read;
wire hdd_write;
reg  hdd_protect;
reg  cpu_wait_hdd = 0;

/*
	reg state = 0;
	reg old_ack = 0;
	reg hdd_read_pending = 0;
	reg hdd_write_pending = 0;
always @(posedge clk_sys) begin

	old_ack <= sd_ack[1];
	hdd_read_pending <= hdd_read_pending | hdd_read;
	hdd_write_pending <= hdd_write_pending | hdd_write;

	if (img_mounted[1]) begin
		hdd_mounted <= img_size != 0;
		hdd_protect <= img_readonly;
	end

	if(reset) begin
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
*/






// [12:9] -- this is the track number



assign      sd_lba[0] = lba_fdd;
wire  [5:0] track;
reg   [3:0] track_sec;
reg         cpu_wait_fdd = 0;
reg  [31:0] lba_fdd;
reg       fd_write_pending = 0;

	reg       wr_state=0;
	reg [5:0] cur_track;
	reg       fdd_mounted = 0;


always @(posedge clk_sys) begin
	reg       old_ack ;
	reg       state ;
	
	old_ack <= sd_ack[0];
	fdd_mounted <= fdd_mounted | img_mounted[0];
	sd_wr[0] <= 0;

	if(reset) begin
		state <= 0;
		cpu_wait_fdd <= 0;
		sd_rd[0] <= 0;
		fd_write_pending<=0;
	end
	else if(!state) begin
		if((cur_track != track) || (fdd_mounted && ~img_mounted[0])) begin
//$display("img_mounted %x size %x",img_mounted,img_size);
			cur_track <= track;
			fdd_mounted <= 0;
			if(img_size) begin
$display("img_mounted %x size %x track %x",img_mounted,img_size,track);
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



always @(posedge clk_sys) begin
	//if (sd_buff_wr & sd_ack[0]) $display(" track sec %x sd_buff_addr %x data %x lba %x",track_sec,sd_buff_addr,sd_buff_dout,sd_lba[0]);
	//$display(" floppy_addr %x %x %x",floppyaddr,track,fd_track_addr);
	//$display(" floppy_addr %x %x ",FLOPPY_ADDRESS,FLOPPY_DATA_IN);
end

wire [17:0] floppyaddr = track * 13'd6656 + fd_track_addr;
wire [17:0] FLOPPY_ADDRESS;
wire [7:0]  FLOPPY_DATA_IN;
/*
bram #(8,18) floppy_dpram
(
	.clock_a(clk_sys),
	.address_a(ioctl_addr),
	.wren_a(ioctl_wr& ioctl_download),
	.data_a(ioctl_dout),
	.q_a(),

	.clock_b(clk_sys),
	.address_b(FLOPPY_ADDRESS),
	.wren_b(1'b0),
	.data_b(fd_data_do),
	.q_b(FLOPPY_DATA_IN)
);
*/
/*
bram #(8,18) floppy_dpram
(
	.clock_a(clk_sys),
	.address_a(ioctl_addr),
	.wren_a(ioctl_wr& ioctl_download),
	.data_a(ioctl_dout),
	.q_a(),

	.clock_b(clk_sys),
	.address_b(floppyaddr),
	.wren_b(1'b0),// fd_write_disk
	.data_b(fd_data_do),
	.q_b(fd_data_in_broken)
);
*/

/*
always @(posedge clk_sys)
	if (fd_read_disk && fd_data_in!=fd_data_in_broken) $display("data is broken track %x fd_track_addr %x  data %x != %x",track,fd_track_addr,fd_data_in,fd_data_in_broken);
*/

wire [7:0] fd_data_in_broken;

bram #(8,14) floppy_dpram_onetrack
(
	.clock_a(clk_sys),
	.address_a({1'b0,track_sec, sd_buff_addr}),
	.wren_a(sd_buff_wr & sd_ack[0]),
	.data_a(sd_buff_dout),
	.q_a(),
	
	.clock_b(clk_sys),
	.address_b(fd_track_addr),
	.wren_b(1'b0), // fd_write_disk
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

	



/* verilator lint_on PINMISSING */

// Debug defines
`define DEBUG_SIMULATION


endmodule 

