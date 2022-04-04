// ****
// T65(b) core. In an effort to merge and maintain bug fixes ....
//
// See list of changes in T65 top file (T65.vhd)...
//
// ****
// 65xx compatible microprocessor core
//
// FPGAARCADE SVN: $Id: T65_ALU.vhd 1234 2015-02-28 20:14:50Z wolfgang.scherr $
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
// Limitations :
//   See in T65 top file (T65.vhd)...

module T65_ALU(
    Mode,
    Op,
    BusA,
    BusB,
    P_In,
    P_Out,
    Q
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
    
    parameter [3:0]  T_Set_BusA_To_Set_BusA_To_DI = 0,
                     T_Set_BusA_To_Set_BusA_To_ABC = 1,
                     T_Set_BusA_To_Set_BusA_To_X = 2,
                     T_Set_BusA_To_Set_BusA_To_Y = 3,
                     T_Set_BusA_To_Set_BusA_To_S = 4,
                     T_Set_BusA_To_Set_BusA_To_P = 5,
                     T_Set_BusA_To_Set_BusA_To_DA = 6,
                     T_Set_BusA_To_Set_BusA_To_DAO = 7,
                     T_Set_BusA_To_Set_BusA_To_DAX = 8,
                     T_Set_BusA_To_Set_BusA_To_AAX = 9,
                     T_Set_BusA_To_Set_BusA_To_DONTCARE = 10;
    
    parameter [1:0]  T_Set_Addr_To_Set_Addr_To_PBR = 0,
                     T_Set_Addr_To_Set_Addr_To_SP = 1,
                     T_Set_Addr_To_Set_Addr_To_ZPG = 2,
                     T_Set_Addr_To_Set_Addr_To_BA = 3;
    
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
    input [1:0]      Mode;		// "00" => 6502, "01" => 65C02, "10" => 65816
    input [4:0]      Op;
    input [7:0]      BusA;
    input [7:0]      BusB;
    input [7:0]      P_In;
    output reg [7:0] P_Out;
    output reg [7:0] Q;
    
    
    // AddSub variables (temporary signals)
    reg              ADC_Z;
    reg              ADC_C;
    reg              ADC_V;
    reg              ADC_N;
    reg [7:0]        ADC_Q;
    reg              SBC_Z;
    reg              SBC_C;
    reg              SBC_V;
    reg              SBC_N;
    reg [7:0]        SBC_Q;
    reg [7:0]        SBX_Q;
    
    
    always @(*)
    begin: xhdl0
        reg [6:0]        AL;
        reg [6:0]        AH;
        reg              C;
        AL = {BusA[3:0], P_In[Flag_C]} + {BusB[3:0], 1'b1};
        AH = {BusA[7:4], AL[5]} + {BusB[7:4], 1'b1};
        
        // pragma translate_off
        //if (is_x(AL))
	if (^AL === 1'bx)
            AL = 7'b0000000;
	if (^AH === 1'bx)
        //if (is_x(AH))
            AH = 7'b0000000;
        // pragma translate_on
        
        if (AL[4:1] == 0 & AH[4:1] == 0)
            ADC_Z = 1'b1;
        else
            ADC_Z = 1'b0;
        
        if (AL[5:1] > 9 & P_In[Flag_D] == 1'b1)
            AL[6:1] = AL[6:1] + 6;
        
        C = AL[6] | AL[5];
        AH = {BusA[7:4], C} + {BusB[7:4], 1'b1};
        
        ADC_N = AH[4];
        ADC_V = (AH[4] ^ BusA[7]) & (~(BusA[7] ^ BusB[7]));
        
        // pragma translate_off
        //if (is_x(AH))
	if (^AH === 1'bx)
            AH = 7'b0000000;
        // pragma translate_on
        
        if (AH[5:1] > 9 & P_In[Flag_D] == 1'b1)
            AH[6:1] = AH[6:1] + 6;
        
        ADC_C = AH[6] | AH[5];
        
        ADC_Q = ({AH[4:1], AL[4:1]});
    end
    
    
    always @(*)
    begin: xhdl1
        reg [6:0]        AL;
        reg [5:0]        AH;
        reg              C;
        reg              CT;
        CT = 1'b0;
        //"0001" These OpCodes used to have LSB set
        //"0011"
        //"0101"
        //"0111"
        //"1001"
        //"1011"
        //         Op=ALU_OP_EQ3 or	--"1101"
        if (Op == T_ALU_OP_ALU_OP_AND | Op == T_ALU_OP_ALU_OP_ADC | Op == T_ALU_OP_ALU_OP_EQ2 | Op == T_ALU_OP_ALU_OP_SBC | Op == T_ALU_OP_ALU_OP_ROL | Op == T_ALU_OP_ALU_OP_ROR | Op == T_ALU_OP_ALU_OP_INC)		//"1111"
            CT = 1'b1;
        
        C = P_In[Flag_C] | (~CT);		//was: or not Op(0);
        AL = {BusA[3:0], C} - {BusB[3:0], 1'b1};
        AH = {BusA[7:4], 1'b0} - {BusB[7:4], AL[5]};
        
        // pragma translate_off
	if (^AL === 1'bx)
        //if (is_x(AL))
            AL = 7'b0000000;
	if (^AH === 1'bx)
        //if (is_x(AH))
            AH = 6'b000000;
        // pragma translate_on
        
        if (AL[4:1] == 0 & AH[4:1] == 0)
            SBC_Z = 1'b1;
        else
            SBC_Z = 1'b0;
        
        SBC_C = (~AH[5]);
        SBC_V = (AH[4] ^ BusA[7]) & (BusA[7] ^ BusB[7]);
        SBC_N = AH[4];
        
        SBX_Q = ({AH[4:1], AL[4:1]});
        
        if (P_In[Flag_D] == 1'b1)
        begin
            if (AL[5] == 1'b1)
                AL[5:1] = AL[5:1] - 6;
            AH = {BusA[7:4], 1'b0} - {BusB[7:4], AL[6]};
            if (AH[5] == 1'b1)
                AH[5:1] = AH[5:1] - 6;
        end
        
        SBC_Q = ({AH[4:1], AL[4:1]});
    end
    
    
    always @(*)
    begin: xhdl2
        reg [7:0]        Q_t;
        reg [7:0]        Q2_t;
        // ORA, AND, EOR, ADC, NOP, LD, CMP, SBC
        // ASL, ROL, LSR, ROR, BIT, LD, DEC, INC
        P_Out = P_In;
        Q_t = BusA;
        Q2_t = BusA;
        case (Op)
            T_ALU_OP_ALU_OP_OR :
                Q_t = BusA | BusB;
            T_ALU_OP_ALU_OP_AND :
                Q_t = BusA & BusB;
            T_ALU_OP_ALU_OP_EOR :
                Q_t = BusA ^ BusB;
            T_ALU_OP_ALU_OP_ADC :
                begin
                    P_Out[Flag_V] = ADC_V;
                    P_Out[Flag_C] = ADC_C;
                    Q_t = ADC_Q;
                end
            T_ALU_OP_ALU_OP_CMP :
                P_Out[Flag_C] = SBC_C;
            T_ALU_OP_ALU_OP_SAX :
                begin
                    P_Out[Flag_C] = SBC_C;
                    Q_t = SBX_Q;		// undoc: subtract (A & X) - (immediate)
                end
            T_ALU_OP_ALU_OP_SBC :
                begin
                    P_Out[Flag_V] = SBC_V;
                    P_Out[Flag_C] = SBC_C;
                    Q_t = SBC_Q;		// undoc: subtract  (A & X) - (immediate), then decimal correction
                end
            T_ALU_OP_ALU_OP_ASL :
                begin
                    Q_t = {BusA[6:0], 1'b0};
                    P_Out[Flag_C] = BusA[7];
                end
            T_ALU_OP_ALU_OP_ROL :
                begin
                    Q_t = {BusA[6:0], P_In[Flag_C]};
                    P_Out[Flag_C] = BusA[7];
                end
            T_ALU_OP_ALU_OP_LSR :
                begin
                    Q_t = {1'b0, BusA[7:1]};
                    P_Out[Flag_C] = BusA[0];
                end
            T_ALU_OP_ALU_OP_ROR :
                begin
                    Q_t = {P_In[Flag_C], BusA[7:1]};
                    P_Out[Flag_C] = BusA[0];
                end
            T_ALU_OP_ALU_OP_ARR :
                begin
                    Q_t = {P_In[Flag_C], (BusA[7:1] & BusB[7:1])};
                    P_Out[Flag_V] = Q_t[5] ^ Q_t[6];
                    Q2_t = Q_t;
                    if (P_In[Flag_D] == 1'b1)
                    begin
                        if ((BusA[3:0] & BusB[3:0]) > 4'b0100)
                            Q2_t[3:0] = ((Q_t[3:0]) + 4'h6);
                        if ((BusA[7:4] & BusB[7:4]) > 4'b0100)
                        begin
                            Q2_t[7:4] = ((Q_t[7:4]) + 4'h6);
                            P_Out[Flag_C] = 1'b1;
                        end
                        else
                            P_Out[Flag_C] = 1'b0;
                    end
                    else
                        P_Out[Flag_C] = Q_t[6];
                end
            T_ALU_OP_ALU_OP_BIT :
                P_Out[Flag_V] = BusB[6];
            T_ALU_OP_ALU_OP_DEC :
                Q_t = (BusA - 1);
            T_ALU_OP_ALU_OP_INC :
                Q_t = (BusA + 1);
            default :
                ;
        endcase
        //EQ1,EQ2,EQ3 passes BusA to Q_t and P_in to P_out
        
        case (Op)
            T_ALU_OP_ALU_OP_ADC :
                begin
                    P_Out[Flag_N] = ADC_N;
                    P_Out[Flag_Z] = ADC_Z;
                end
            T_ALU_OP_ALU_OP_CMP, T_ALU_OP_ALU_OP_SBC, T_ALU_OP_ALU_OP_SAX :
                begin
                    P_Out[Flag_N] = SBC_N;
                    P_Out[Flag_Z] = SBC_Z;
                end
            T_ALU_OP_ALU_OP_EQ1 :		//dont touch P
                ;
            T_ALU_OP_ALU_OP_BIT :
                begin
                    P_Out[Flag_N] = BusB[7];
                    if ((BusA & BusB) == 8'b00000000)
                        P_Out[Flag_Z] = 1'b1;
                    else
                        P_Out[Flag_Z] = 1'b0;
                end
            T_ALU_OP_ALU_OP_ANC :
                begin
                    P_Out[Flag_N] = Q_t[7];
                    P_Out[Flag_C] = Q_t[7];
                    if (Q_t == 8'b00000000)
                        P_Out[Flag_Z] = 1'b1;
                    else
                        P_Out[Flag_Z] = 1'b0;
                end
            default :
                begin
                    P_Out[Flag_N] = Q_t[7];
                    if (Q_t == 8'b00000000)
                        P_Out[Flag_Z] = 1'b1;
                    else
                        P_Out[Flag_Z] = 1'b0;
                end
        endcase
        
        if (Op == T_ALU_OP_ALU_OP_ARR)
            // handled above in ARR code
            Q = Q2_t;
        else
            Q = Q_t;
    end
    
endmodule
`undef T65_Pack
