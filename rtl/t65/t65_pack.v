// ****
// T65(b) core. In an effort to merge and maintain bug fixes ....
//
// See list of changes in T65 top file (T65.vhd)...
//
// ****
// 65xx compatible microprocessor core
//
// FPGAARCADE SVN: $Id: T65_Pack.vhd 1234 2015-02-28 20:14:50Z wolfgang.scherr $
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

`ifndef t65_pack
`define t65_pack


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
//"0000"
//"0001"
//"0010"
//"0011"
//"0100" EQ1 does not change N,Z flags, EQ2/3 does.
//"0101" Not sure yet whats the difference between EQ2&3. They seem to do the same ALU op
//"0110"
//"0111"
//"1000"
//"1001"
//"1010"
//"1011"
//"1100"
//    ALU_OP_EQ3,  --"1101"
//"1110"
//"1111"
//    ALU_OP_UNDEF--"----"--may be replaced with any?

// instruction
// A reg
// X reg
// Y reg
// stack pointer
// processor flags

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

`endif
