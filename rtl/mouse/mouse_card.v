


module mouse(

    input         IO_SELECT_N,
    input  [15:0] ADDRESS,
    input         RW_N,
    // input SYNC -- only slot 7
    input         IO_STROBE_N,
    //output        RDY,
    //input       DMA,
    output        IRQ_N,
    //output        NMI_N,
    input         RESET,
    //input         INH_N,
    input         CLK_14M,
  //  input         CLK_7M,
    input         CLK_2M,
    input         PH_2,
    input         DEVICE_SELECT_N,
    input  [7:0]  DATA_IN,
    output [7:0]  DATA_OUT,
    output   ROM_EN

    // mouse pass through to the framework

);


//  The Mouse Card has 
//  a 2k rom.
//  The 256byte section actually starts at address 0x700
//  The full 2k rom is mapped in when the card is selected (into a shared
//  address space)
//
//  All cards unamp their 2k rom when they see CFFF1
//  

//
// Mouse Rom
//
wire [7:0] DOA_C8S;
wire [7:0] MOUSE;


/*
  Map and Unmap the ROM - setup ROM_EN and ENA_C8S
*/
reg				SLOTCXROM;
wire				ENA_C8S;
reg				C8S2;
wire APPLE_C0;


assign APPLE_C0	= (ADDRESS[15:8]	== 8'b11000000) ? 1'b1: 1'b0;

always @(posedge CLK_14M)
begin
	if(RESET)
	begin
		SLOTCXROM <= 1'b0;
	end
	else
	begin
			if(~RW_N)
			begin
				case({APPLE_C0, ADDRESS[7:0]})
				9'h106:		SLOTCXROM <= 1'b0;
				9'h107:		SLOTCXROM <= 1'b1;
				endcase
			end
	end
end


always @ (posedge CLK_14M)
begin
	if(RESET)
	begin
		C8S2 <= 1'b0;
	end
	else
	begin
		case (ADDRESS[15:8])
		8'hC2:
		begin
			if(!SLOTCXROM)								// SSC ROM
				C8S2 <= 1'b1;
		end
		8'hCF:
		begin
			if(!SLOTCXROM)
			begin
				if(ADDRESS[7:0] == 8'hFF)
				  C8S2 <= 1'b0;
			end
		end
		endcase
	end
end

assign ENA_C8S = ({(C8S2 & !SLOTCXROM),ADDRESS[15:11]} == 6'b111001) ? 1'b1: 1'b0;
assign ROM_EN = ENA_C8S;
																									
/*
always @(posedge CLK_14M)
begin
         //if ((ADDRESS[3:0]  == 4'hC))
         if ((ADDRESS[15:0]  == 16'hC205))
		$display("IO_SELECT_N %x ROM_EN %x IO_STROBE_N %x DEVICE_SELECT_N %x ADDR %x ROM_ADDR %x RW_N %x DOA_C8S %x DATA_OUT %x",IO_SELECT_N,ROM_EN,IO_STROBE_N,DEVICE_SELECT_N,ADDRESS,ROM_ADDR,RW_N,DOA_C8S,DATA_OUT);
end
*/

wire [10:0] ROM_ADDR = ROM_EN ? ADDRESS[10:0] : {3'b000 ,ADDRESS[7:0]} ;
assign DATA_OUT = ~IO_SELECT_N ? DOA_C8S : (ROM_EN & ~IO_STROBE_N) ? DOA_C8S : MOUSE;

   rom #(8,11,"rtl/roms/mouse.hex") roms (
           .clock(CLK_14M),
           .ce(1'b1),
           .a(ROM_ADDR),
           .data_out(DOA_C8S)
   );




endmodule

