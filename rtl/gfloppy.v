module gfloppy
(
	input RESET_N,
	input PH_2,
	input [15:0] ADDRESS ,
	output [17:0] FLOPPY_ADDRESS,
	output [7:0] FLOPPY_DATA,
	input [7:0] FLOPPY_DATA_IN,
	input [7:0] DATA_OUT
);

reg	[12:0]	FLOPPY_BYTE;
reg	[4:0]		FLOPPY_CLK;
reg	[1:0]		STEPPER1;
reg	[1:0]		STEPPER2;
reg	[16:0]	TRACK1;
reg	[16:0]	TRACK2;
wire	[16:0]	TRACK;
wire	[16:0]	TRACK1_UP;
wire	[16:0]	TRACK1_DOWN;
wire	[16:0]	TRACK2_UP;
wire	[16:0]	TRACK2_DOWN;
wire           FLOPPY_VALID;
//wire	[17:0]	FLOPPY_ADDRESS;
reg	[7:0]		FLOPPY_WRITE_DATA;
reg	[7:0]		LAST_WRITE_DATA;
wire	[7:0]		FLOPPY_RD_DATA;
//wire	[7:0]		FLOPPY_DATA;
wire				FLOPPY_READ;
wire				FLOPPY_WRITE;
wire				FLOPPY_WP_READ;
reg				PHASE0;
reg				PHASE0_1;
reg				PHASE0_2;
reg				PHASE1;
reg				PHASE1_1;
reg				PHASE1_2;
reg				PHASE2;
reg				PHASE2_1;
reg				PHASE2_2;
reg				PHASE3;
reg				PHASE3_1;
reg				PHASE3_2;
reg				DRIVE1;
reg				MOTOR;
reg				Q6;
reg				Q7;
wire				DRIVE1_EN;
wire				DRIVE2_EN;
wire				DRIVE1_X;
wire				DRIVE2_X;

wire [7:0] SWITCH={ 1'b0, 1'b0, 1'b0,1'b0, 1'b0, 1'b0, 1'b0,1'b0,1'b0};
// Extra Buttons and Switches
//  7 System type 1	Not used
											//  6 System type 0	Not used
											//  5 IRQ Disable
											//  4 Swap floppy
											//  3 Write protect floppy 2
											//  2 Write protect floppy 1
											//  1 CPU_SPEED[1]
											//  0 CPU_SPEED[0]

wire SLOT_6IO	= (ADDRESS[15:4] == 12'hC0E) ? 1'b1: 1'b0; 

/*****************************************************************************
* Floppy
******************************************************************************/
// 6312 bytes per track
// New byte every 32 CPU clock cycles 
// or 8 bits * 4 clock cycles
always @(negedge PH_2 or negedge RESET_N)
begin
	if(!RESET_N)
	begin
		FLOPPY_CLK <= 5'b00000;
		LAST_WRITE_DATA <= 8'b00;
	end
	else
	begin
		if(FLOPPY_WRITE)
		begin
			FLOPPY_CLK <= FLOPPY_CLK + 1'b1;
			LAST_WRITE_DATA <= FLOPPY_WRITE_DATA;
		end
		else
		begin
			if(!(Q7 && (FLOPPY_CLK == 5'b00000) && (LAST_WRITE_DATA == 8'hFF)))
				FLOPPY_CLK <= FLOPPY_CLK + 1'b1;
		end
	end
end

always @(negedge PH_2 or negedge RESET_N)
begin
	if(!RESET_N)
	begin
		PHASE0 <= 1'b0;
		PHASE1 <= 1'b0;
		PHASE2 <= 1'b0;
		PHASE3 <= 1'b0;
		MOTOR <= 1'b0;
		DRIVE1<= 1'b1;
		FLOPPY_WRITE_DATA <= 8'h00;
	end
	else
	begin
		case ({SLOT_6IO, ADDRESS[3:0]})
		5'h10:	PHASE0 <= 1'b0;
		5'h11:	PHASE0 <= 1'b1;
		5'h12:	PHASE1 <= 1'b0;
		5'h13:	PHASE1 <= 1'b1;
		5'h14:	PHASE2 <= 1'b0;
		5'h15:	PHASE2 <= 1'b1;
		5'h16:	PHASE3 <= 1'b0;
		5'h17:	PHASE3 <= 1'b1;
		5'h18:	MOTOR <= 1'b0;
		5'h19:	MOTOR <= 1'b1;
		5'h1A:	DRIVE1 <= 1'b1;
		5'h1B:	DRIVE1 <= 1'b0;
		5'h1C:	Q6 <= 1'b0;
		5'h1D:
		begin
				FLOPPY_WRITE_DATA <= DATA_OUT[7:0];
				Q6 <= 1'b1;
		end
		5'h1E:	Q7 <= 1'b0;
		5'h1F:
		begin
				FLOPPY_WRITE_DATA <= DATA_OUT[7:0];
				Q7 <= 1'b1;
		end

		endcase
	end
end

assign DRIVE1_X =  DRIVE1 & MOTOR;
assign DRIVE2_X = !DRIVE1 & MOTOR;

assign DRIVE1_EN = (SWITCH[4] ^  DRIVE1) & MOTOR;
assign DRIVE2_EN = (SWITCH[4] ^ !DRIVE1) & MOTOR;
assign FLOPPY_READ		= ({Q7, SLOT_6IO, ADDRESS[3:0]} == 6'h1C)	?	1'b1:
																							1'b0;
assign FLOPPY_WRITE		= ({Q7, SLOT_6IO, ADDRESS[3:0]} == 6'h3C)	?	1'b1:
																							1'b0;
assign FLOPPY_WP_READ	= ({Q6, SLOT_6IO, ADDRESS[3:0]} == 6'h3E)	?	1'b1:
																							1'b0;

assign FLOPPY_VALID 		=	(!FLOPPY_CLK[4] & !FLOPPY_CLK[3]);

assign FLOPPY_RD_DATA	=	DRIVE1_EN	?	{FLOPPY_VALID, FLOPPY_DATA_IN[6:0]}:
									DRIVE2_EN	?	{FLOPPY_VALID, FLOPPY_DATA_IN[6:0]}:
														8'H00;

assign FLOPPY_DATA		=	(FLOPPY_READ)									?	FLOPPY_RD_DATA:
									({DRIVE1_EN, FLOPPY_WP_READ} == 2'b11)	?	{SWITCH[2], 7'h00}:
									({DRIVE2_EN, FLOPPY_WP_READ} == 2'b11)	?	{SWITCH[3], 7'h00}:
									(FLOPPY_WRITE)									?	FLOPPY_WRITE_DATA:
																							8'h00;

always @(posedge FLOPPY_CLK[4])
begin
	case(FLOPPY_BYTE)
	13'h18A7:
		FLOPPY_BYTE <= 13'h0000;
	default:
		FLOPPY_BYTE <= FLOPPY_BYTE + 1'b1;
	endcase
end

assign TRACK		=	(DRIVE1_EN)		?	TRACK1:
							(DRIVE2_EN)		?	TRACK2:
													TRACK;

assign TRACK1_UP = TRACK1 + 12'h62A;
assign TRACK1_DOWN = TRACK1 - 12'h62A;
assign TRACK2_UP = TRACK2 + 12'h62A;
assign TRACK2_DOWN = TRACK2 - 12'h62A;

assign FLOPPY_ADDRESS = {TRACK, 1'b0} + {5'b00000, FLOPPY_BYTE};

always @ (posedge PH_2)
begin
	PHASE0_1 <= PHASE0;
	PHASE0_2 <= PHASE0_1;					// Delay 2 clock cycles
	PHASE1_1 <= PHASE1;
	PHASE1_2 <= PHASE1_1;					// Delay 2 clock cycles
	PHASE2_1 <= PHASE2;
	PHASE2_2 <= PHASE2_1;					// Delay 2 clock cycles
	PHASE3_1 <= PHASE3;
	PHASE3_2 <= PHASE3_1;					// Delay 2 clock cycles
end

always @(negedge PH_2 or negedge RESET_N)
begin
	if(!RESET_N)
	begin
		STEPPER1 <= 2'b00;
		STEPPER2 <= 2'b00;
		TRACK1 <= 17'd00000;
		TRACK2 <= 17'd00000;
	end
	else
	begin
		if(DRIVE1^SWITCH[4])
		begin
			case ({PHASE0_2, PHASE1_2, PHASE2_2, PHASE3_2})
			4'b1000:
			begin
				if(STEPPER1 == 2'b11)
				begin
					if(TRACK1 != 17'h1E0CC)
					begin
						TRACK1 <= TRACK1_UP;
						STEPPER1 <= 2'b00;
					end
				end
				else
				if(STEPPER1 == 2'b01)
				begin
					if(TRACK1 != 17'h0)
					begin
						TRACK1 <= TRACK1_DOWN;
						STEPPER1 <= 2'b00;
					end
				end
			end
			4'b0100:
			begin
				if(STEPPER1 == 2'b00)
				begin
					if(TRACK1 != 17'h1E0CC)
					begin
						TRACK1 <= TRACK1_UP;
						STEPPER1 <= 2'b01;
					end
				end
				else
				if(STEPPER1 == 2'b10)
				begin
					if(TRACK1 != 17'h0)
					begin
						TRACK1 <= TRACK1_DOWN;
						STEPPER1 <= 2'b01;
					end
				end
			end
			4'b0010:
			begin
				if(STEPPER1 == 2'b01)
				begin
					if(TRACK1 != 17'h1E0CC)
					begin
						TRACK1 <= TRACK1_UP;
						STEPPER1 <= 2'b10;
					end
				end
				else
				if(STEPPER1 == 2'b11)
				begin
					if(TRACK1 != 17'h0)
					begin
						TRACK1 <= TRACK1_DOWN;
						STEPPER1 <= 2'b10;
					end
				end
			end
			4'b0001:
			begin
				if(STEPPER1 == 2'b10)
				begin
					if(TRACK1 != 17'h1E0CC)
					begin
						TRACK1 <= TRACK1_UP;
						STEPPER1 <= 2'b11;
					end
				end
				else
				if(STEPPER1 == 2'b00)
				begin
					if(TRACK1 != 17'h0)
					begin
						TRACK1 <= TRACK1_DOWN;
						STEPPER1 <= 2'b11;
					end
				end
			end
			endcase
		end
		else
		begin
			case ({PHASE0_2, PHASE1_2, PHASE2_2, PHASE3_2})
			4'b1000:
			begin
				if(STEPPER2 == 2'b11)
				begin
					if(TRACK2 != 17'h1E0CC)
					begin
						TRACK2 <= TRACK2_UP;
						STEPPER2 <= 2'b00;
					end
				end
				else
				if(STEPPER2 == 2'b01)
				begin
					if(TRACK2 != 17'h0)
					begin
						TRACK2 <= TRACK2_DOWN;
						STEPPER2 <= 2'b00;
					end
				end
			end
			4'b0100:
			begin
				if(STEPPER2 == 2'b00)
				begin
					if(TRACK2 != 17'h1E0CC)
					begin
						TRACK2 <= TRACK2_UP;
						STEPPER2 <= 2'b01;
					end
				end
				else
				if(STEPPER2 == 2'b10)
				begin
					if(TRACK2 != 17'h0)
					begin
						TRACK2 <= TRACK2_DOWN;
						STEPPER2 <= 2'b01;
					end
				end
			end
			4'b0010:
			begin
				if(STEPPER2 == 2'b01)
				begin
					if(TRACK2 != 17'h1E0CC)
					begin
						TRACK2 <= TRACK2_UP;
						STEPPER2 <= 2'b10;
					end
				end
				else
				if(STEPPER2 == 2'b11)
				begin
					if(TRACK2 != 17'h0)
					begin
						TRACK2 <= TRACK2_DOWN;
						STEPPER2 <= 2'b10;
					end
				end
			end
			4'b0001:
			begin
				if(STEPPER2 == 2'b10)
				begin
					if(TRACK2 != 17'h1E0CC)
					begin
						TRACK2 <= TRACK2_UP;
						STEPPER2 <= 2'b11;
					end
				end
				else
				if(STEPPER2 == 2'b00)
				begin
					if(TRACK2 != 17'h0)
					begin
						TRACK2 <= TRACK2_DOWN;
						STEPPER2 <= 2'b11;
					end
				end
			end
			endcase
		end
	end
end
endmodule
