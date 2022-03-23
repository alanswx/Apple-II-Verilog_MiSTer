// ****
// T65(b) core. In an effort to merge and maintain bug fixes ....
//
// Ver 315 SzGy April 2020
//   Reduced the IRQ detection delay when RDY is not asserted (NMI?)
//   Undocumented opcodes behavior change during not RDY and page boundary crossing (VICE tests - cpu/sha, cpu/shs, cpu/shxy)
//
// Ver 313 WoS January 2015
//   Fixed issue that NMI has to be first if issued the same time as a BRK instruction is latched in
//   Now all Lorenz CPU tests on FPGAARCADE C64 core (sources used: SVN version 1021) are OK! :D :D :D
//   This is just a starting point to go for optimizations and detailed fixes (the Lorenz test can't find)
//
// Ver 312 WoS January 2015
//   Undoc opcode timing fixes for $B3 (LAX iy) and $BB (LAS ay)
//   Added comments in MCode section to find handling of individual opcodes more easily
//   All "basic" Lorenz instruction test (individual functional checks, CPUTIMING check) work now with 
//       actual FPGAARCADE C64 core (sources used: SVN version 1021).
//
// Ver 305, 306, 307, 308, 309, 310, 311 WoS January 2015
//   Undoc opcode fixes (now all Lorenz test on instruction functionality working, except timing issues on $B3 and $BB):
//     SAX opcode
//     SHA opcode
//     SHX opcode
//     SHY opcode
//     SHS opcode
//     LAS opcode
//     alternate SBC opcode
//     fixed NOP with immediate param (caused Lorenz trap test to fail)
//     IRQ and NMI timing fixes (in conjuction with branches)
//
// Ver 304 WoS December 2014
//   Undoc opcode fixes:
//     ARR opcode
//     ANE/XAA opcode
//   Corrected issue with NMI/IRQ prio (when asserted the same time)
//
// Ver 303 ost(ML) July 2014
//   (Sorry for some scratchpad comments that may make little sense)
//   Mods and some 6502 undocumented instructions.
//   Not correct opcodes acc. to Lorenz tests (incomplete list):
//     NOPN    (nop)
//     NOPZX   (nop + byte 172)
//     NOPAX   (nop + word da  ...  da:  byte 0)
//     ASOZ    (byte $07 + byte 172)
//
// Ver 303,302 WoS April 2014
//     Bugfixes for NMI from foft
//     Bugfix for BRK command (and its special flag)
//
// Ver 300,301 WoS January 2014
//     More merging
//     Bugfixes by ehenciak added, started tidyup *bust*
//
// MikeJ March 2005
//      Latest version from www.fpgaarcade.com (original www.opencores.org)
// ****
//
// 65xx compatible microprocessor core
//
// FPGAARCADE SVN: $Id: T65.vhd 1347 2015-05-27 20:07:34Z wolfgang.scherr $
//
// Copyright (c) 2002...2015
//               Daniel Wallner (jesus <at> opencores <dot> org)
//               Mike Johnson   (mikej <at> fpgaarcade <dot> com)
//               Wolfgang Scherr (WoS <at> pin4 <dot> at>
//               Morten Leikvoll ()
//
// All rights reserved
//
// Redistribution and use in source and synthezised forms, with or without
// modification, are permitted provided that the following conditions are met:
//
// Redistributions of source code must retain the above copyright notice,
// this list of conditions and the following disclaimer.
//
// Redistributions in synthesized form must reproduce the above copyright
// notice, this list of conditions and the following disclaimer in the
// documentation and/or other materials provided with the distribution.
//
// Neither the name of the author nor the names of other contributors may
// be used to endorse or promote products derived from this software without
// specific prior written permission.
//
// THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
// AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
// THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
// PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE AUTHOR OR CONTRIBUTORS BE
// LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
// CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF
// SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS
// INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN
// CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE)
// ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
// POSSIBILITY OF SUCH DAMAGE.
//
// Please report bugs to the author(s), but before you do so, please
// make sure that this is not a derivative work and that
// you have the latest version of this file.
//
// ----- IMPORTANT NOTES -----
//
// Limitations:
//   65C02 and 65C816 modes are incomplete (and definitely untested after all 6502 undoc fixes)
//      65C02 supported : inc, dec, phx, plx, phy, ply
//      65D02 missing : bra, ora, lda, cmp, sbc, tsb*2, trb*2, stz*2, bit*2, wai, stp, jmp, bbr*8, bbs*8
//   Some interface signals behave incorrect
//   NMI interrupt handling not nice, needs further rework (to cycle-based encoding).
//
// Usage:
//   The enable signal allows clock gating / throttling without using the ready signal.
//   Set it to constant '1' when using the Clk input as the CPU clock directly.
//
//   TAKE CARE you route the DO signal back to the DI signal while R_W_n='0',
//   otherwise some undocumented opcodes won't work correctly.
//   EXAMPLE:
//      CPU : entity work.T65
//          port map (
//              R_W_n   => cpu_rwn_s,
//              [....all other ports....]
//              DI      => cpu_din_s,
//              DO      => cpu_dout_s
//          );
//      cpu_din_s <= cpu_dout_s when cpu_rwn_s='0' else 
//                   [....other sources from peripherals and memories...]
//
// ----- IMPORTANT NOTES -----
//

module T65(
    Mode,
    Res_n,
    Enable,
    Clk,
    Rdy,
    Abort_n,
    IRQ_n,
    NMI_n,
    SO_n,
    R_W_n,
    Sync,
    EF,
    MF,
    XF,
    ML_n,
    VP_n,
    VDA,
    VPA,
    A,
    DI,
    DO,
    Regs,
    DEBUG_I,
    DEBUG_A,
    DEBUG_X,
    DEBUG_Y,
    DEBUG_S,
    DEBUG_P,
    NMI_ack,
    PRINT
);
    // begin code from package t65_pack
    
    
    
    parameter        Flag_C = 0;
    parameter        Flag_Z = 1;
    parameter        Flag_I = 2;
    parameter        Flag_D = 3;
    parameter        Flag_B = 4;
    parameter        Flag_1 = 5;
    parameter        Flag_V = 6;
    parameter        Flag_N = 7;
    
    parameter [2:0]  Cycle_sync = 3'b000;
    parameter [2:0]  Cycle_1 = 3'b001;
    parameter [2:0]  Cycle_2 = 3'b010;
    parameter [2:0]  Cycle_3 = 3'b011;
    parameter [2:0]  Cycle_4 = 3'b100;
    parameter [2:0]  Cycle_5 = 3'b101;
    parameter [2:0]  Cycle_6 = 3'b110;
    parameter [2:0]  Cycle_7 = 3'b111;
    
    parameter [3:0]  T_Set_BusA_To_Set_BusA_To_DI = 0;
    parameter [3:0]                  T_Set_BusA_To_Set_BusA_To_ABC = 1;
                   parameter [3:0]   T_Set_BusA_To_Set_BusA_To_X = 2;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_Y = 3;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_S = 4;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_P = 5;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_DA = 6;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_DAO = 7;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_DAX = 8;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_AAX = 9;
                     parameter [3:0] T_Set_BusA_To_Set_BusA_To_DONTCARE = 10;
    
    parameter [1:0]  T_Set_Addr_To_Set_Addr_To_PBR = 0;
    parameter [1:0]  T_Set_Addr_To_Set_Addr_To_SP = 1;
    parameter [1:0]  T_Set_Addr_To_Set_Addr_To_ZPG = 2;
    parameter [1:0]  T_Set_Addr_To_Set_Addr_To_BA = 3;
    
    parameter [3:0]  T_Write_Data_Write_Data_DL = 0,
                     T_Write_Data_Write_Data_ABC = 1,
                     T_Write_Data_Write_Data_X = 2,
                     T_Write_Data_Write_Data_Y = 3,
                     T_Write_Data_Write_Data_S = 4,
                     T_Write_Data_Write_Data_P = 5,
                     T_Write_Data_Write_Data_PCL = 6,
                     T_Write_Data_Write_Data_PCH = 7,
                     T_Write_Data_Write_Data_AX = 8,
                     T_Write_Data_Write_Data_AXB = 9,
                     T_Write_Data_Write_Data_XB = 10,
                     T_Write_Data_Write_Data_YB = 11,
                     T_Write_Data_Write_Data_DONTCARE = 12;
    
    parameter [4:0]  T_ALU_OP_ALU_OP_OR = 0,
                     T_ALU_OP_ALU_OP_AND = 1,
                     T_ALU_OP_ALU_OP_EOR = 2,
                     T_ALU_OP_ALU_OP_ADC = 3,
                     T_ALU_OP_ALU_OP_EQ1 = 4,
                     T_ALU_OP_ALU_OP_EQ2 = 5,
                     T_ALU_OP_ALU_OP_CMP = 6,
                     T_ALU_OP_ALU_OP_SBC = 7,
                     T_ALU_OP_ALU_OP_ASL = 8,
                     T_ALU_OP_ALU_OP_ROL = 9,
                     T_ALU_OP_ALU_OP_LSR = 10,
                     T_ALU_OP_ALU_OP_ROR = 11,
                     T_ALU_OP_ALU_OP_BIT = 12,
                     T_ALU_OP_ALU_OP_DEC = 13,
                     T_ALU_OP_ALU_OP_INC = 14,
                     T_ALU_OP_ALU_OP_ARR = 15,
                     T_ALU_OP_ALU_OP_ANC = 16,
                     T_ALU_OP_ALU_OP_SAX = 17,
                     T_ALU_OP_ALU_OP_XAA = 18;
    
    
    function [2:0] CycleNext;
       input [2:0]      c;
    begin
       case (c)
          Cycle_sync :
             CycleNext = Cycle_1;
          Cycle_1 :
             CycleNext = Cycle_2;
          Cycle_2 :
             CycleNext = Cycle_3;
          Cycle_3 :
             CycleNext = Cycle_4;
          Cycle_4 :
             CycleNext = Cycle_5;
          Cycle_5 :
             CycleNext = Cycle_6;
          Cycle_6 :
             CycleNext = Cycle_7;
          Cycle_7 :
             CycleNext = Cycle_sync;
          default :
             CycleNext = Cycle_sync;
       endcase
    end
    endfunction
    
    // end code from package t65_pack
    input [1:0]   Mode;		// "00" => 6502, "01" => 65C02, "10" => 65C816
    input         Res_n;
    input         Enable;
    input         Clk;
    input         Rdy;
    input         Abort_n;
    input         IRQ_n;
    input         NMI_n;
    input         SO_n;
    output        R_W_n;
    output        Sync;
    output        EF;
    output        MF;
    output        XF;
    output        ML_n;
    output        VP_n;
    output        VDA;
    output        VPA;
    output [23:0] A;
    input [7:0]   DI;
    output reg [7:0]  DO;
    // 6502 registers (MSB) PC, SP, P, Y, X, A (LSB)
    output [63:0] Regs;
    output [7:0]  DEBUG_I;
    output [7:0]  DEBUG_A;
    output [7:0]  DEBUG_X;
    output [7:0]  DEBUG_Y;
    output [7:0]  DEBUG_S;
    output [7:0]  DEBUG_P;
    output        NMI_ack;
    
   output reg PRINT; 
    
    // Registers
    reg [15:0]    ABC;
    reg [15:0]    X;
    reg [15:0]    Y;
    reg [7:0]     P;
    reg [7:0]     AD;
    reg [7:0]     DL;
    wire [7:0]    PwithB;		//ML:New way to push P with correct B state to stack
    reg [7:0]     BAH;
    reg [8:0]     BAL;
    reg [7:0]     PBR;
    reg [7:0]     DBR;
    reg [15:0]    PC;
    reg [15:0]    S;
    reg           EF_i;
    reg           MF_i;
    reg           XF_i;
    
    reg [7:0]     IR;
    reg [2:0]     MCycle;
    
    wire [7:0]    DO_r;
    
    reg [1:0]     Mode_r;
    reg [4:0]     ALU_Op_r;
    reg [3:0]     Write_Data_r;
    reg [1:0]     Set_Addr_To_r;
    wire [8:0]    PCAdder;
    
    reg           RstCycle;
    reg           IRQCycle;
    reg           NMICycle;
    
    reg           SO_n_o;
    reg           IRQ_n_o;
    reg           NMI_n_o;
    reg           NMIAct;
    
    wire          Break;
    
    // ALU signals
    wire [7:0]    BusA;
    reg [7:0]     BusA_r;
    reg [7:0]     BusB;
    reg [7:0]     BusB_r;
    wire [7:0]    ALU_Q;
    wire [7:0]    P_Out;
    
    // Micro code outputs
    wire [2:0]    LCycle;
    wire [4:0]    ALU_Op;
    wire [3:0]    Set_BusA_To;
    wire [1:0]    Set_Addr_To;
    wire [3:0]    Write_Data;
    wire [1:0]    Jump;
    wire [1:0]    BAAdd;
    wire [1:0]    BAQuirk;
    wire          BreakAtNA;
    wire          ADAdd;
    wire          AddY;
    wire          PCAdd;
    wire          Inc_S;
    wire          Dec_S;
    wire          LDA;
    wire          LDP;
    wire          LDX;
    wire          LDY;
    wire          LDS;
    wire          LDDI;
    wire          LDALU;
    wire          LDAD;
    wire          LDBAL;
    wire          LDBAH;
    wire          SaveP;
    wire          Write;
    
    reg           Res_n_i;
    reg           Res_n_d;
    
    reg           rdy_mod;		// RDY signal turned off during the instruction
    wire          really_rdy;
    reg           WRn_i;
    
    reg           NMI_entered;
    
    assign NMI_ack = NMIAct;
    
    // gate Rdy with read/write to make an "OK, it's really OK to stop the processor 
    assign really_rdy = Rdy | (~(WRn_i));
    assign Sync = (MCycle == 3'b000) ? 1'b1 : 
                  1'b0;
    assign EF = EF_i;
    assign MF = MF_i;
    assign XF = XF_i;
    assign R_W_n = WRn_i;
    assign ML_n = (IR[7:6] != 2'b10 & IR[2:1] == 2'b11 & MCycle[2:1] != 2'b00) ? 1'b0 : 
                  1'b1;
    assign VP_n = (IRQCycle == 1'b1 & (MCycle == 3'b101 | MCycle == 3'b110)) ? 1'b0 : 
                  1'b1;
    assign VDA = (Set_Addr_To_r != T_Set_Addr_To_Set_Addr_To_PBR) ? 1'b1 : 
                 1'b0;
    assign VPA = (Jump[1] == 1'b0) ? 1'b1 : 
                 1'b0;
    
    // debugging signals
    assign DEBUG_I = IR;
    assign DEBUG_A = ABC[7:0];
    assign DEBUG_X = X[7:0];
    assign DEBUG_Y = Y[7:0];
    assign DEBUG_S = (S[7:0]);
    assign DEBUG_P = P;
    
    assign Regs = {PC, S, P, Y[7:0], X[7:0], ABC[7:0]};
/*
    always @(posedge Clk)
    begin
         PRINT<=0;
	    if ((PC >= 'hC500 && PC <'hC600) || (PC>='hFF50&&PC<'hFF70))
	    begin
	    PRINT<=1;
		    $display("PC %x IR %x A %x X %x DEBUG_X %x Y %x S %x P %x ADDR %x DI %x DO %x",PC,IR,ABC,X,DEBUG_X,Y,S,P,A,DI,DO);
	    end
    end
 */   
    
    T65_MCode mcode(

        //inputs
        .Mode(Mode_r),
        .IR(IR),
        .MCycle(MCycle),
        .P(P),
        .Rdy_mod(rdy_mod),
        //outputs
        .LCycle(LCycle),
        .ALU_Op(ALU_Op),
        .Set_BusA_To(Set_BusA_To),
        .Set_Addr_To(Set_Addr_To),
        .Write_Data(Write_Data),
        .Jump(Jump),
        .BAAdd(BAAdd),
        .BAQuirk(BAQuirk),
        .BreakAtNA(BreakAtNA),
        .ADAdd(ADAdd),
        .AddY(AddY),
        .PCAdd(PCAdd),
        .Inc_S(Inc_S),
        .Dec_S(Dec_S),
        .LDA(LDA),
        .LDP(LDP),
        .LDX(LDX),
        .LDY(LDY),
        .LDS(LDS),
        .LDDI(LDDI),
        .LDALU(LDALU),
        .LDAD(LDAD),
        .LDBAL(LDBAL),
        .LDBAH(LDBAH),
        .SaveP(SaveP),
        .Write(Write)
    );
    
    
    T65_ALU alu(
        .Mode(Mode_r),
        .Op(ALU_Op_r),
        .BusA(BusA_r),
        .BusB(BusB),
        .P_In(P),
        .P_Out(P_Out),
        .Q(ALU_Q)
    );
    
    // the 65xx design requires at least two clock cycles before
    // starting its reset sequence (according to datasheet)
    

    always @(negedge Res_n or posedge Clk)
        if (Res_n == 1'b0)
        begin
            Res_n_i <= 1'b0;
            Res_n_d <= 1'b0;
        end
        else 
        begin
            Res_n_i <= Res_n_d;
            Res_n_d <= 1'b1;
        end
    
    
    always @(negedge Res_n_i or posedge Clk)
        if (Res_n_i == 1'b0)
        begin
            PC <= {16{1'b0}};		// Program Counter
            IR <= 8'b00000000;
            S <= {16{1'b0}};		// Dummy
            PBR <= {8{1'b0}};
            DBR <= {8{1'b0}};
            
            Mode_r <= {2{1'b0}};
            ALU_Op_r <= T_ALU_OP_ALU_OP_BIT;
            Write_Data_r <= T_Write_Data_Write_Data_DL;
            Set_Addr_To_r <= T_Set_Addr_To_Set_Addr_To_PBR;
            
            WRn_i <= 1'b1;
            EF_i <= 1'b1;
            MF_i <= 1'b1;
            XF_i <= 1'b1;
        end
        
        else 
        begin
            if (Enable == 1'b1)
            begin
                // some instructions behavior changed by the Rdy line. Detect this at the correct cycles.
                if (MCycle == 3'b000)
                    rdy_mod <= 1'b0;
                else if (((MCycle == 3'b011 & IR != 8'h93) | (MCycle == 3'b100 & IR == 8'h93)) & Rdy == 1'b0)
                    rdy_mod <= 1'b1;
                
                if (really_rdy == 1'b1)
                begin
                    WRn_i <= (~Write) | RstCycle;
                    
                    PBR <= {8{1'b1}};		// Dummy
                    DBR <= {8{1'b1}};		// Dummy
                    EF_i <= 1'b0;		// Dummy
                    MF_i <= 1'b0;		// Dummy
                    XF_i <= 1'b0;		// Dummy
                    
                    if (MCycle == 3'b000)
                    begin
                        Mode_r <= Mode;
                        
                        if (IRQCycle == 1'b0 & NMICycle == 1'b0)
                            PC <= PC + 1;
                        
                        if (IRQCycle == 1'b1 | NMICycle == 1'b1)
                            IR <= 8'b00000000;
                        else
                            IR <= DI;
                        
                        if (LDS == 1'b1)		// LAS won't work properly if not limited to machine cycle 0
                            S[7:0] <= ALU_Q;
                    end
                    
                    ALU_Op_r <= ALU_Op;
                    Write_Data_r <= Write_Data;
                    if (Break == 1'b1)
                        Set_Addr_To_r <= T_Set_Addr_To_Set_Addr_To_PBR;
                    else
                        Set_Addr_To_r <= Set_Addr_To;
                    
                    if (Inc_S == 1'b1)
                        S <= S + 1;
                    if (Dec_S == 1'b1 & RstCycle == 1'b0)
                        S <= S - 1;
                    
                    if (IR == 8'b00000000 & MCycle == 3'b001 & IRQCycle == 1'b0 & NMICycle == 1'b0)
                        PC <= PC + 1;
                    //
                    // jump control logic
                    //
                    case (Jump)
                        2'b01 :
                            PC <= PC + 1;
                        2'b10 :
                            PC <= ({DI, DL});
                        2'b11 :
                            begin
                                if (PCAdder[8] == 1'b1)
                                begin
                                    if (DL[7] == 1'b0)
                                        PC[15:8] <= PC[15:8] + 1;
                                    else
                                        PC[15:8] <= PC[15:8] - 1;
                                end
                                PC[7:0] <= PCAdder[7:0];
                            end
                        default :
                            ;
                    endcase
                end
            end
        end
    
    assign PCAdder = (PCAdd == 1'b1) ? PC[7:0] + {DL[7], DL} : {1'b0, PC[7:0]};
    
    
    always @(negedge Res_n_i or posedge Clk)
    begin: xhdl0
        reg [7:0]     tmpP;		//Lets try to handle loading P at mcycle=0 and set/clk flags at same cycle
        if (Res_n_i == 1'b0)
            P <= 8'h00;		// ensure we have nothing set on reset
        else 
        begin
            tmpP = P;
            if (Enable == 1'b1)
            begin
                if (really_rdy == 1'b1)
                begin
                    if (MCycle == 3'b000)
                    begin
                        if (LDA == 1'b1)
                            ABC[7:0] <= ALU_Q;
                        if (LDX == 1'b1)
                            X[7:0] <= ALU_Q;
                        if (LDY == 1'b1)
                            Y[7:0] <= ALU_Q;
                        if ((LDA | LDX | LDY) == 1'b1)
                            tmpP = P_Out;
                    end
                    if (SaveP == 1'b1)
                        tmpP = P_Out;
                    if (LDP == 1'b1)
                        tmpP = ALU_Q;
                    if (IR[4:0] == 5'b11000)
                        case (IR[7:5])
                            3'b000 :		//0x18(clc)
                                tmpP[Flag_C] = 1'b0;
                            3'b001 :		//0x38(sec)
                                tmpP[Flag_C] = 1'b1;
                            3'b010 :		//0x58(cli)
                                tmpP[Flag_I] = 1'b0;
                            3'b011 :		//0x78(sei)
                                tmpP[Flag_I] = 1'b1;
                            3'b101 :		//0xb8(clv)
                                tmpP[Flag_V] = 1'b0;
                            3'b110 :		//0xd8(cld)
                                tmpP[Flag_D] = 1'b0;
                            3'b111 :		//0xf8(sed)
                                tmpP[Flag_D] = 1'b1;
                            default :
                                ;
                        endcase
                    tmpP[Flag_B] = 1'b1;
                    if (IR == 8'b00000000 & MCycle == 3'b100 & RstCycle == 1'b0)
                        //This should happen after P has been pushed to stack
                        tmpP[Flag_I] = 1'b1;
                    if (RstCycle == 1'b1)
                    begin
                        tmpP[Flag_I] = 1'b1;
                        tmpP[Flag_D] = 1'b0;
                    end
                    tmpP[Flag_1] = 1'b1;
                    
                    P <= tmpP;		//new way
                end
                
                // detect irq even if not rdy
                if (IR[4:0] != 5'b10000 | Jump != 2'b01 | really_rdy == 1'b0)		// delay interrupts during branches (checked with Lorenz test and real 6510), not best way yet, though - but works...
                    IRQ_n_o <= IRQ_n;
                // detect nmi even if not rdy
                if (IR[4:0] != 5'b10000 | Jump != 2'b01)		// delay interrupts during branches (checked with Lorenz test and real 6510) not best way yet, though - but works...
                    NMI_n_o <= NMI_n;
            end
            // act immediately on SO pin change
            // The signal is sampled on the trailing edge of phi1 and must be externally synchronized (from datasheet)
            SO_n_o <= SO_n;
            if (SO_n_o == 1'b1 & SO_n == 1'b0)
                P[Flag_V] <= 1'b1;
        end
    end
    
    //-------------------------------------------------------------------------
    //
    // Buses
    //
    //-------------------------------------------------------------------------
    
    
    always @(negedge Res_n_i or posedge Clk)
        if (Res_n_i == 1'b0)
        begin
            BusA_r <= {8{1'b0}};
            BusB <= {8{1'b0}};
            BusB_r <= {8{1'b0}};
            AD <= {8{1'b0}};
            BAL <= {9{1'b0}};
            BAH <= {8{1'b0}};
            DL <= {8{1'b0}};
        end
        else 
        begin
            if (Enable == 1'b1)
            begin
                if (really_rdy == 1'b1)
                begin
                    NMI_entered <= 1'b0;
                    BusA_r <= BusA;
                    BusB <= DI;
                    
                    // not really nice, but no better way found yet !
                    if (Set_Addr_To_r == T_Set_Addr_To_Set_Addr_To_PBR | Set_Addr_To_r == T_Set_Addr_To_Set_Addr_To_ZPG)
                        BusB_r <= ((DI[7:0]) + 1);		// required for SHA
                    
                    case (BAAdd)
                        2'b01 :
                            begin
                                // BA Inc
                                AD <= (AD + 1);
                                BAL <= (BAL + 1);
                            end
                        2'b10 :
                            // BA Add
                            BAL <= (BAL[7:0] + BusA);
                        2'b11 :
                            // BA Adj
                            if (BAL[8] == 1'b1)
                                // Handle quirks with some undocumented opcodes crossing page boundary
                                case (BAQuirk)
                                    2'b00 :		// no quirk
                                        BAH <= (BAH + 1);
                                    2'b01 :
                                        BAH <= (BAH + 1) & DO_r;
                                    2'b10 :
                                        BAH <= DO_r;
                                    default :
                                        ;
                                endcase
                        default :
                            ;
                    endcase
                    
                    // modified to use Y register as well
                    if (ADAdd == 1'b1)
                    begin
                        if (AddY == 1'b1)
                            AD <= (AD + (Y[7:0]));
                        else
                            AD <= (AD + (X[7:0]));
                    end
                    
                    if (IR == 8'b00000000)
                    begin
                        BAL <= {9{1'b1}};
                        BAH <= {8{1'b1}};
                        if (RstCycle == 1'b1)
                            BAL[2:0] <= 3'b100;
                        else if (NMICycle == 1'b1 | (NMIAct == 1'b1 & MCycle == 3'b100) | NMI_entered == 1'b1)
                        begin
                            BAL[2:0] <= 3'b010;
                            if (MCycle == 3'b100)
                                NMI_entered <= 1'b1;
                        end
                        else
                            BAL[2:0] <= 3'b110;
                        if (Set_Addr_To_r == T_Set_Addr_To_Set_Addr_To_BA)
                            BAL[0] <= 1'b1;
                    end
                    
                    if (LDDI == 1'b1)
                        DL <= DI;
                    if (LDALU == 1'b1)
                        DL <= ALU_Q;
                    if (LDAD == 1'b1)
                        AD <= DI;
                    if (LDBAL == 1'b1)
                        BAL[7:0] <= DI;
                    if (LDBAH == 1'b1)
                        BAH <= DI;
                end
            end
        end
    
    assign Break = (BreakAtNA & (~BAL[8])) | (PCAdd & (~PCAdder[8]));
    
    assign BusA = (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_DI) ? DI : 
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_ABC) ? ABC[7:0] : 
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_X) ? X[7:0] : 
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_Y) ? Y[7:0] : 
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_S) ? (S[7:0]) : 
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_P) ? P : 
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_DA) ? ABC[7:0] & DI : 
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_DAO) ? (ABC[7:0] | 8'hee) & DI : 		//ee for OAL instruction. constant may be different on other platforms.TODO:Move to generics
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_DAX) ? (ABC[7:0] | 8'hee) & DI & X[7:0] : 		//XAA, ee for OAL instruction. constant may be different on other platforms.TODO:Move to generics
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_AAX) ? ABC[7:0] & X[7:0] : 		//SAX, SHA
                  (Set_BusA_To == T_Set_BusA_To_Set_BusA_To_DONTCARE) ? 1'bx : 	0;	//Can probably remove this
    
    assign A = (Set_Addr_To_r == T_Set_Addr_To_Set_Addr_To_SP) ? {16'b0000000000000001, (S[7:0])} : 
               (Set_Addr_To_r == T_Set_Addr_To_Set_Addr_To_ZPG) ? {DBR, 8'b00000000, AD} : 
               (Set_Addr_To_r == T_Set_Addr_To_Set_Addr_To_BA) ? {8'b00000000, BAH, BAL[7:0]} : 
               (Set_Addr_To_r == T_Set_Addr_To_Set_Addr_To_PBR) ? {PBR, (PC[15:8]), (PCAdder[7:0])}  : 0;
    
    // This is the P that gets pushed on stack with correct B flag. I'm not sure if NMI also clears B, but I guess it does.
    assign PwithB = ((IRQCycle == 1'b1 | NMICycle == 1'b1)) ? (P & 8'hef) : 
                    P;
    
    assign DO = DO_r;
    
    assign DO_r = (Write_Data_r == T_Write_Data_Write_Data_DL) ? DL : 
                  (Write_Data_r == T_Write_Data_Write_Data_ABC) ? ABC[7:0] : 
                  (Write_Data_r == T_Write_Data_Write_Data_X) ? X[7:0] : 
                  (Write_Data_r == T_Write_Data_Write_Data_Y) ? Y[7:0] : 
                  (Write_Data_r == T_Write_Data_Write_Data_S) ? (S[7:0]) : 
                  (Write_Data_r == T_Write_Data_Write_Data_P) ? PwithB : 
                  (Write_Data_r == T_Write_Data_Write_Data_PCL) ? (PC[7:0]) : 
                  (Write_Data_r == T_Write_Data_Write_Data_PCH) ? (PC[15:8]) : 
                  (Write_Data_r == T_Write_Data_Write_Data_AX) ? ABC[7:0] & X[7:0] : 
                  (Write_Data_r == T_Write_Data_Write_Data_AXB) ? ABC[7:0] & X[7:0] & BusB_r[7:0] : 		// no better way found yet...
                  (Write_Data_r == T_Write_Data_Write_Data_XB) ? X[7:0] & BusB_r[7:0] : 		// no better way found yet...
                  (Write_Data_r == T_Write_Data_Write_Data_YB) ? Y[7:0] & BusB_r[7:0] : 		// no better way found yet...
                  (Write_Data_r == T_Write_Data_Write_Data_DONTCARE) ? {8{1'bx}} : 0; 		//Can probably remove this
    
    //-----------------------------------------------------------------------
    //
    // Main state machine
    //
    //-----------------------------------------------------------------------
    
    
    always @(negedge Res_n_i or posedge Clk)
        if (Res_n_i == 1'b0)
        begin
            MCycle <= 3'b001;
            RstCycle <= 1'b1;
            IRQCycle <= 1'b0;
            NMICycle <= 1'b0;
            NMIAct <= 1'b0;
        end
        else 
        begin
            if (Enable == 1'b1)
            begin
                if (really_rdy == 1'b1)
                begin
                    if (MCycle == LCycle | Break == 1'b1)
                    begin
                        MCycle <= 3'b000;
                        RstCycle <= 1'b0;
                        IRQCycle <= 1'b0;
                        NMICycle <= 1'b0;
                        if (NMIAct == 1'b1 && IR != 8'h00)		// delay NMI further if we just executed a BRK
                        begin
                            NMICycle <= 1'b1;
                            NMIAct <= 1'b0;		// reset NMI edge detector if we start processing the NMI
                        end
                        else if (IRQ_n_o == 1'b0 && P[Flag_I] == 1'b0)
                            IRQCycle <= 1'b1;
                    end
                    else
                        MCycle <= (MCycle + 1);
                end
                //detect NMI even if not rdy    
                if (NMI_n_o == 1'b1 & (NMI_n == 1'b0 & (IR[4:0] != 5'b10000 | Jump != 2'b01)))		// branches have influence on NMI start (not best way yet, though - but works...)
                    NMIAct <= 1'b1;
                // we entered NMI during BRK instruction
                if (NMI_entered == 1'b1)
                    NMIAct <= 1'b0;
            end
        end
    
endmodule
`undef T65_Pack
