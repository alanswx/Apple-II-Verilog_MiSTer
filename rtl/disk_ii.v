

module disk_ii(CLK_14M, CLK_2M, PHASE_ZERO, IO_SELECT, DEVICE_SELECT, RESET, DISK_READY, A, D_IN, D_OUT, D1_ACTIVE, D2_ACTIVE, TRACK1, TRACK1_ADDR, TRACK1_DI, TRACK1_DO, TRACK1_WE, TRACK1_BUSY, TRACK2, TRACK2_ADDR, TRACK2_DI, TRACK2_DO, TRACK2_WE, TRACK2_BUSY);
   input        CLK_14M;
   input        CLK_2M;
   input        PHASE_ZERO;
   input        IO_SELECT;
   input        DEVICE_SELECT;
   input        RESET;
   input [1:0]  DISK_READY;
   input [15:0]  A;
   input [7:0]  D_IN;
   output [7:0] D_OUT;
   output       D1_ACTIVE;
   output       D2_ACTIVE;
   output [5:0] TRACK1;
   output [12:0] TRACK1_ADDR;
   output [7:0] TRACK1_DI;
   input [7:0]  TRACK1_DO;
   output       TRACK1_WE;
   input        TRACK1_BUSY;
   output [5:0] TRACK2;
   output [12:0] TRACK2_ADDR;
   output [7:0] TRACK2_DI;
   input [7:0]  TRACK2_DO;
   output       TRACK2_WE;
   input        TRACK2_BUSY;
   
   reg [3:0]    motor_phase;
   reg          drive_on;
   reg          drive_real_on;
   reg          drive2_select;
   reg          q6;
   reg          q7;
   wire         CLK_2M_D;
   
   wire [7:0]   rom_dout;
   wire [7:0]   d_out1;
   wire [7:0]   d_out2;
   
   wire [7:0]   phase;
   
   wire [12:0]   track_byte_addr;
   wire         read_disk;
   wire         write_reg;
   wire [7:0]   data_reg;
   wire         reset_data_reg;
   wire         write_mode;
   
   
   always @(posedge CLK_14M)
   begin: interpret_io
      
      begin
         if (RESET == 1'b1)
         begin
            motor_phase <= {4{1'b0}};
            drive_on <= 1'b0;
            drive2_select <= 1'b0;
            q6 <= 1'b0;
            q7 <= 1'b0;
         end
         else
            if (DEVICE_SELECT == 1'b1)
            begin
               if (A[3] == 1'b0)
                  motor_phase[(A[2:1])] <= A[0];
               else
                  case (A[2:1])
                     2'b00 :
                        drive_on <= A[0];
                     2'b01 :
                        drive2_select <= A[0];
                     2'b10 :
                        q6 <= A[0];
                     2'b11 :
                        q7 <= A[0];
                     default :
                        ;
                  endcase
            end
      end
   end
   
   
   always @(posedge CLK_14M or posedge RESET)
   begin: drive_on_delay
      reg [23:0]    spindown_delay;
      reg          drive_on_old;
      if (RESET == 1'b1)
      begin
         spindown_delay = {24{1'b0}};
         drive_real_on <= 1'b0;
      end
      else 
      begin
         if (spindown_delay != 0)
         begin
            spindown_delay = spindown_delay - 1;
            if (spindown_delay == 0)
               drive_real_on <= 1'b0;
         end
         
         if (drive_on == 1'b1)
         begin
            spindown_delay = {24{1'b0}};
            drive_real_on <= 1'b1;
         end
         else if (drive_on_old == 1'b1)
            spindown_delay = 14000000;
         
         drive_on_old = drive_on;
      end
   end
   
   assign D1_ACTIVE = drive_real_on & (~drive2_select);
   assign D2_ACTIVE = drive_real_on & drive2_select;
   assign write_mode = q7;
   
   assign read_disk = (DEVICE_SELECT == 1'b1 & A[3:0] == 4'hC) ? 1'b1 : 
                      1'b0;
   assign write_reg = (DEVICE_SELECT == 1'b1 & A[3:2] == 2'b11 & A[0] == 1'b1) ? 1'b1 : 
                      1'b0;
   
   assign D_OUT = (IO_SELECT == 1'b1) ? rom_dout : 
                  (q6 == 1'b0) ? data_reg : 
                  8'h00;
   assign data_reg = (drive2_select == 1'b0) ? d_out1 : 
                     d_out2;
   
   
   drive_ii drive_1(.CLK_14M(CLK_14M), .CLK_2M(CLK_2M), .PHASE_ZERO(PHASE_ZERO), .RESET(RESET), .DISK_READY(DISK_READY[0]), .D_IN(D_IN), .D_OUT(d_out1), .DISK_ACTIVE(D1_ACTIVE), .MOTOR_PHASE(motor_phase), .WRITE_MODE(write_mode), .READ_DISK(read_disk), .WRITE_REG(write_reg), .TRACK(TRACK1), .TRACK_ADDR(TRACK1_ADDR), .TRACK_DI(TRACK1_DI), .TRACK_DO(TRACK1_DO), .TRACK_WE(TRACK1_WE), .TRACK_BUSY(TRACK1_BUSY));
   
   
   drive_ii drive_2(.CLK_14M(CLK_14M), .CLK_2M(CLK_2M), .PHASE_ZERO(PHASE_ZERO), .RESET(RESET), .DISK_READY(DISK_READY[1]), .D_IN(D_IN), .D_OUT(d_out2), .DISK_ACTIVE(D2_ACTIVE), .MOTOR_PHASE(motor_phase), .WRITE_MODE(write_mode), .READ_DISK(read_disk), .WRITE_REG(write_reg), .TRACK(TRACK2), .TRACK_ADDR(TRACK2_ADDR), .TRACK_DI(TRACK2_DI), .TRACK_DO(TRACK2_DO), .TRACK_WE(TRACK2_WE), .TRACK_BUSY(TRACK2_BUSY));
   
  
   rom #(8,8,"rtl/roms/diskii.hex") diskrom (
           .clock(CLK_14M),
           .ce(1'b1),
           .a(A[7:0]),
           .data_out(rom_dout)
   );
   //disk_ii_rom rom(.addr(A[7:0]), .clk(CLK_14M), .dout(rom_dout));
   
endmodule
