//-----------------------------------------------------------------------
//
// This is a systemverilog conversion of table driven 65Cx2 core by A.Daly
// This is a derivative of the excellent FPGA64 core see below
//
//-----------------------------------------------------------------------
// Copyright 2005-2008 by Peter Wendrich (pwsoft@syntiac.com)
// http://www.syntiac.com/fpga64.html
// SystemVerilog conversion Copyright 2022 Frank Bruno (fbruno@asicsolutions.com)
// http://www.asicsolutions.com
//-----------------------------------------------------------------------

module R65C02
  (
   input wire          reset,
   input wire          clk,
   input wire          enable,
   input wire          nmi_n,
   input wire          irq_n,
   input wire [7:0]    di,
   output logic [7:0]  dout,
   output logic [15:0] addr,
   output logic        nwe,
   output logic        sync,
   output logic        sync_irq,
   // 6502 registers (MSB) PC, SP, P, Y, X, A (LSB)
   output logic [63:0] Regs
   );

  // Store Zp    (3) => fetch, cycle2, cycleEnd
  // Store Zp,x  (4) => fetch, cycle2, preWrite, cycleEnd
  // Read  Zp,x  (4) => fetch, cycle2, cycleRead, cycleRead2
  // Rmw   Zp,x  (6) => fetch, cycle2, cycleRead, cycleRead2, cycleRmw, cycleEnd
  // Store Abs   (4) => fetch, cycle2, cycle3, cycleEnd
  // Store Abs,x (5) => fetch, cycle2, cycle3, preWrite, cycleEnd
  // Rts         (6) => fetch, cycle2, cycle3, cycleRead, cycleJump, cycleIncrEnd
  // Rti         (6) => fetch, cycle2, stack1, stack2, stack3, cycleJump
  // Jsr         (6) => fetch, cycle2, .. cycle5, cycle6, cycleJump
  // Jmp abs     (-) => fetch, cycle2, .., cycleJump
  // Jmp (ind)   (-) => fetch, cycle2, .., cycleJump
  // Brk / irq   (6) => fetch, cycle2, stack2, stack3, stack4
  ////////////////////////////////////////////////////////////////////////-

  //	signal counter : unsigned(27 downto 0);
  //	signal mask_irq : std_logic;
  //	signal mask_enable : std_logic;
  // Statemachine

  typedef enum bit [4:0]
               {
                opcodeFetch,      // New opcode is read and registers updated
                cycle2,
                cycle3,
                cyclePreIndirect,
                cycleIndirect,
                cycleBranchTaken,
                cycleBranchPage,
                cyclePreRead,     // Cycle before read while doing zeropage indexed addressing.
                cycleRead,        // Read cycle
                cycleRead2,       // Second read cycle after page-boundary crossing.
                cycleRmw,         // Calculate ALU output for read-modify-write instr.
                cyclePreWrite,    // Cycle before write when doing indexed addressing.
                cycleWrite,       // Write cycle for zeropage or absolute addressing.
                cycleStack1,
                cycleStack2,
                cycleStack3,
                cycleStack4,
                cycleJump,	  // Last cycle of Jsr, Jmp. Next fetch address is target addr.
                cycleEnd
                } cpuCycles_t;

  cpuCycles_t theCpuCycle;
  cpuCycles_t nextCpuCycle;

  logic        updateRegisters;
  logic        processIrq;
  logic        nmiReg;
  logic        nmiEdge;
  logic        irqReg;               // Delay IRQ input with one clock cycle.
  logic        soReg;                // SO pin edge detection

  // Opcode decoding
  localparam opcUpdateA    = 0;
  localparam opcUpdateX    = 1;
  localparam opcUpdateY    = 2;
  localparam opcUpdateS    = 3;
  localparam opcUpdateN    = 4;
  localparam opcUpdateV    = 5;
  localparam opcUpdateD    = 6;
  localparam opcUpdateI    = 7;
  localparam opcUpdateZ    = 8;
  localparam opcUpdateC    = 9;

  localparam opcSecondByte = 10;
  localparam opcAbsolute   = 11;
  localparam opcZeroPage   = 12;
  localparam opcIndirect   = 13;
  localparam opcStackAddr  = 14; // Push/Pop address
  localparam opcStackData  = 15; // Push/Pop status/data
  localparam opcJump       = 16;
  localparam opcBranch     = 17;
  localparam indexX        = 18;
  localparam indexY        = 19;
  localparam opcStackUp    = 20;
  localparam opcWrite      = 21;
  localparam opcRmw        = 22;
  localparam opcIncrAfter  = 23; // Insert extra cycle to increment PC (RTS)
  localparam opcRti        = 24;
  localparam opcIRQ        = 25;


  localparam opcInA        = 26;
  localparam opcInBrk      = 27;
  localparam opcInX        = 28;
  localparam opcInY        = 29;
  localparam opcInS        = 30;
  localparam opcInT        = 31;
  localparam opcInH        = 32;
  localparam opcInClear    = 33;

  localparam aluMode1From  = 34;
  //
  localparam aluMode1To    = 37;

  localparam aluMode2From  = 38;
  //
  localparam aluMode2To    = 40;
  //
  localparam opcInCmp      = 41;
  localparam opcInCpx      = 42;
  localparam opcInCpy      = 43;

  //
  //         is Interrupt  -----------------+
  //    instruction is RTI ----------------+|
  //PC++ on last cyc (RTS) ---------------+||
  //                RMW    --------------+|||
  //               Write   -------------+||||
  //         Pop/Stack up -------------+|||||
  //              Branch   ---------+  ||||||
  //                Jump ----------+|  ||||||
  //      Push or Pop data -------+||  ||||||
  //      Push or Pop addr ------+|||  ||||||
  //             Indirect  -----+||||  ||||||
  //              ZeroPage ----+|||||  ||||||
  //              Absolute ---+||||||  ||||||
  //        PC++ on cycle2 --+|||||||  ||||||
  //                         |AZI||JBXY|WM|||
  localparam immediate = 16'b1000000000000000;
  localparam implied   = 16'b0000000000000000;
  // Zero page
  localparam readZp    = 16'b1010000000000000;
  localparam writeZp   = 16'b1010000000010000;
  localparam rmwZp     = 16'b1010000000001000;
  // Zero page indexed
  localparam readZpX   = 16'b1010000010000000;
  localparam writeZpX  = 16'b1010000010010000;
  localparam rmwZpX    = 16'b1010000010001000;
  localparam readZpY   = 16'b1010000001000000;
  localparam writeZpY  = 16'b1010000001010000;
  localparam rmwZpY    = 16'b1010000001001000;
  // Zero page indirect
  localparam readIndX  = 16'b1001000010000000;
  localparam writeIndX = 16'b1001000010010000;
  localparam rmwIndX   = 16'b1001000010001000;
  localparam readIndY  = 16'b1001000001000000;
  localparam writeIndY = 16'b1001000001010000;
  localparam rmwIndY   = 16'b1001000001001000;
  localparam rmwInd    = 16'b1001000000001000;
  localparam readInd   = 16'b1001000000000000;
  localparam writeInd  = 16'b1001000000010000;
  //                          |AZI||JBXY|WM||
  // Absolute
  localparam readAbs   = 16'b1100000000000000;
  localparam writeAbs  = 16'b1100000000010000;
  localparam rmwAbs    = 16'b1100000000001000;
  localparam readAbsX  = 16'b1100000010000000;
  localparam writeAbsX = 16'b1100000010010000;
  localparam rmwAbsX   = 16'b1100000010001000;
  localparam readAbsY  = 16'b1100000001000000;
  localparam writeAbsY = 16'b1100000001010000;
  localparam rmwAbsY   = 16'b1100000001001000;
  // PHA PHP
  localparam push      = 16'b0000010000000000;
  // PLA PLP
  localparam pop       = 16'b0000010000100000;
  // Jumps
  localparam jsr       = 16'b1000101000000000;
  localparam jumpAbs   = 16'b1000001000000000;
  localparam jumpInd   = 16'b1100001000000000;
  localparam jumpIndX  = 16'b1100001010000000;
  localparam relative  = 16'b1000000100000000;
  // Specials
  localparam rts       = 16'b0000101000100100;
  localparam rti       = 16'b0000111000100010;
  localparam brk       = 16'b1000111000000001;
  //	localparam irq       = 16'b0000111000000001;
  //	localparam        : unsigned(0 to 0) := "0";
  localparam xxxxxxxx  = 16'bxxxxxxxxxx0xxx00;

  // A = accu
  // X = index X
  // Y = index Y
  // S = Stack pointer
  // H = indexH
  //
  //                       AEXYSTHc
  localparam aluInA   = 8'b10000000;
  localparam aluInBrk = 8'b01000000;
  localparam aluInX   = 8'b00100000;
  localparam aluInY   = 8'b00010000;
  localparam aluInS   = 8'b00001000;
  localparam aluInT   = 8'b00000100;
  localparam aluInClr = 8'b00000001;
  localparam aluInSet = 8'b00000000;
  localparam aluInXXX = 8'bxxxxxxxx;

  // Most of the aluModes are just like the opcodes.
  // aluModeInp -> input is output. calculate N and Z
  // aluModeCmp -> Compare for CMP, CPX, CPY
  // aluModeFlg -> input to flags needed for PLP, RTI and CLC, SEC, CLV
  // aluModeInc -> for INC but also INX, INY
  // aluModeDec -> for DEC but also DEX, DEY

  // Logic/Shift ALU
  localparam aluModeInp = 4'b0000;
  localparam aluModeP   = 4'b0001;
  localparam aluModeInc = 4'b0010;
  localparam aluModeDec = 4'b0011;
  localparam aluModeFlg = 4'b0100;
  localparam aluModeBit = 4'b0101;
  // 0110
  // 0111
  localparam aluModeLsr = 4'b1000;
  localparam aluModeRor = 4'b1001;
  localparam aluModeAsl = 4'b1010;
  localparam aluModeRol = 4'b1011;
  localparam aluModeTSB = 4'b1100;
  localparam aluModeTRB = 4'b1101;
  // 1110
  // 1111;

  // Arithmetic ALU
  localparam aluModePss = 3'b000;
  localparam aluModeCmp = 3'b001;
  localparam aluModeAdc = 3'b010;
  localparam aluModeSbc = 3'b011;
  localparam aluModeAnd = 3'b100;
  localparam aluModeOra = 3'b101;
  localparam aluModeEor = 3'b110;
  localparam aluModeNoF = 3'b111;
  //aluModeBRK
  //localparam aluBrk  = {aluModeBRK, aluModePss, 3'bxxx};
  //localparam aluFix  = {aluModeInp, aluModeNoF, 3'bxxx};
  localparam aluInp  = {aluModeInp, aluModePss, 3'bxxx};
  localparam aluP    = {aluModeP,   aluModePss, 3'bxxx};
  localparam aluInc  = {aluModeInc, aluModePss, 3'bxxx};
  localparam aluDec  = {aluModeDec, aluModePss, 3'bxxx};
  localparam aluFlg  = {aluModeFlg, aluModePss, 3'bxxx};
  localparam aluBit  = {aluModeBit, aluModeAnd, 3'bxxx};
  localparam aluRor  = {aluModeRor, aluModePss, 3'bxxx};
  localparam aluLsr  = {aluModeLsr, aluModePss, 3'bxxx};
  localparam aluRol  = {aluModeRol, aluModePss, 3'bxxx};
  localparam aluAsl  = {aluModeAsl, aluModePss, 3'bxxx};
  localparam aluTSB  = {aluModeTSB, aluModePss, 3'bxxx};
  localparam aluTRB  = {aluModeTRB, aluModePss, 3'bxxx};
  localparam aluCmp  = {aluModeInp, aluModeCmp, 3'b100};
  localparam aluCpx  = {aluModeInp, aluModeCmp, 3'b010};
  localparam aluCpy  = {aluModeInp, aluModeCmp, 3'b001};
  localparam aluAdc  = {aluModeInp, aluModeAdc, 3'bxxx};
  localparam aluSbc  = {aluModeInp, aluModeSbc, 3'bxxx};
  localparam aluAnd  = {aluModeInp, aluModeAnd, 3'bxxx};
  localparam aluOra  = {aluModeInp, aluModeOra, 3'bxxx};
  localparam aluEor  = {aluModeInp, aluModeEor, 3'bxxx};

  localparam aluXXX  = 10'bx;

  // Stack operations. Push/Pop/None
  localparam stackInc = 1'b0;
  localparam stackDec = 1'b1;
  localparam stackXXX = 1'bx;

  const logic [0:43] opcodeInfoTable[256] =
                     // +------- Update register A
                     // |+------ Update register X
                     // ||+----- Update register Y
                     // |||+---- Update register S
                     // ||||       +-- Update Flags
                     // ||||       |
                     // ||||      _|__
                     // ||||     /    \
                     // AXYS     NVDIZC    addressing  aluInput  aluMode
                     // AXYS     NVDIZC    addressing  aluInput  aluMode
                     '{{4'b0000, 6'b001100, brk,       aluInBrk, aluP},   // 00 BRK
                       {4'b1000, 6'b100010, readIndX,  aluInT,   aluOra}, // 01 ORA (zp,x)
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // 02 NOP ------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 03 NOP ------- 65C02
                       {4'b0000, 6'b000010, rmwZp,     aluInT,   aluTSB}, // 04 TSB zp ----------- 65C02
                       {4'b1000, 6'b100010, readZp,    aluInT,   aluOra}, // 05 ORA zp
                       {4'b0000, 6'b100011, rmwZp,     aluInT,   aluAsl}, // 06 ASL zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 07 NOP ------- 65C02
                       {4'b0000, 6'b000000, push,      aluInXXX, aluP},   // 08 PHP
                       {4'b1000, 6'b100010, immediate, aluInT,   aluOra}, // 09 ORA imm
                       {4'b1000, 6'b100011, implied,   aluInA,   aluAsl}, // 0A ASL accu
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 0B NOP ------- 65C02
                       {4'b0000, 6'b000010, rmwAbs,    aluInT,   aluTSB}, // 0C TSB abs ---------- 65C02
                       {4'b1000, 6'b100010, readAbs,   aluInT,   aluOra}, // 0D ORA abs
                       {4'b0000, 6'b100011, rmwAbs,    aluInT,   aluAsl}, // 0E ASL abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 0F NOP ------- 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // 10 BPL
                       {4'b1000, 6'b100010, readIndY,  aluInT,   aluOra}, // 11 ORA (zp),y
                       {4'b1000, 6'b100010, readInd,   aluInT,   aluOra}, // 12 ORA (zp) --------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 13 NOP ------- 65C02
                       {4'b0000, 6'b000010, rmwZp,     aluInT,   aluTRB}, // 14 TRB zp ~---------- 65C02
                       {4'b1000, 6'b100010, readZpX,   aluInT,   aluOra}, // 15 ORA zp,x
                       {4'b0000, 6'b100011, rmwZpX,    aluInT,   aluAsl}, // 16 ASL zp,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 17 NOP ------- 65C02
                       {4'b0000, 6'b000001, implied,   aluInClr, aluFlg}, // 18 CLC
                       {4'b1000, 6'b100010, readAbsY,  aluInT,   aluOra}, // 19 ORA abs,y
                       {4'b1000, 6'b100010, implied,   aluInA,   aluInc}, // 1A INC accu --------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 1B NOP ------- 65C02
                       {4'b0000, 6'b000010, rmwAbs,    aluInT,   aluTRB}, // 1C TRB abs ~----- --- 65C02
                       {4'b1000, 6'b100010, readAbsX,  aluInT,   aluOra}, // 1D ORA abs,x
                       {4'b0000, 6'b100011, rmwAbsX,   aluInT,   aluAsl}, // 1E ASL abs,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 1F NOP ------- 65C02
                       // AXYS     NVDIZC    addressing  aluInput  aluMode
                       {4'b0000, 6'b000000, jsr,       aluInXXX, aluXXX}, // 20 JSR
                       {4'b1000, 6'b100010, readIndX,  aluInT,   aluAnd}, // 21 AND (zp,x)
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // 22 NOP ------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 23 NOP ------- 65C02
                       {4'b0000, 6'b110010, readZp,    aluInT,   aluBit}, // 24 BIT zp
                       {4'b1000, 6'b100010, readZp,    aluInT,   aluAnd}, // 25 AND zp
                       {4'b0000, 6'b100011, rmwZp,     aluInT,   aluRol}, // 26 ROL zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 27 NOP ------- 65C02
                       {4'b0000, 6'b111111, pop,       aluInT,   aluFlg}, // 28 PLP
                       {4'b1000, 6'b100010, immediate, aluInT,   aluAnd}, // 29 AND imm
                       {4'b1000, 6'b100011, implied,   aluInA,   aluRol}, // 2A ROL accu
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 2B NOP ------- 65C02
                       {4'b0000, 6'b110010, readAbs,   aluInT,   aluBit}, // 2C BIT abs
                       {4'b1000, 6'b100010, readAbs,   aluInT,   aluAnd}, // 2D AND abs
                       {4'b0000, 6'b100011, rmwAbs,    aluInT,   aluRol}, // 2E ROL abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 2F NOP ------- 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // 30 BMI
                       {4'b1000, 6'b100010, readIndY,  aluInT,   aluAnd}, // 31 AND (zp),y
                       {4'b1000, 6'b100010, readInd,   aluInT,   aluAnd}, // 32 AND (zp) -------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 33 NOP ------- 65C02
                       {4'b0000, 6'b110010, readZpX,   aluInT,   aluBit}, // 34 BIT zp,x -------- 65C02
                       {4'b1000, 6'b100010, readZpX,   aluInT,   aluAnd}, // 35 AND zp,x
                       {4'b0000, 6'b100011, rmwZpX,    aluInT,   aluRol}, // 36 ROL zp,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 37 NOP ------- 65C02
                       {4'b0000, 6'b000001, implied,   aluInSet, aluFlg}, // 38 SEC
                       {4'b1000, 6'b100010, readAbsY,  aluInT,   aluAnd}, // 39 AND abs,y
                       {4'b1000, 6'b100010, implied,   aluInA,   aluDec}, // 3A DEC accu -------- 65C12
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 3B NOP ------- 65C02
                       {4'b0000, 6'b110010, readAbsX,  aluInT,   aluBit}, // 3C BIT abs,x ------- 65C02
                       {4'b1000, 6'b100010, readAbsX,  aluInT,   aluAnd}, // 3D AND abs,x
                       {4'b0000, 6'b100011, rmwAbsX,   aluInT,   aluRol}, // 3E ROL abs,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 3F NOP ------- 65C02
                       // AXYS     NVDIZC    addressing  aluInput  aluMode
                       {4'b0000, 6'b111111, rti,       aluInT,   aluFlg}, // 40 RTI
                       {4'b1000, 6'b100010, readIndX,  aluInT,   aluEor}, // 41 EOR (zp,x)
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // 42 NOP ------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 43 NOP ------- 65C02
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // 44 NOP ------- 65C02
                       {4'b1000, 6'b100010, readZp,    aluInT,   aluEor}, // 45 EOR zp
                       {4'b0000, 6'b100011, rmwZp,     aluInT,   aluLsr}, // 46 LSR zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 47 NOP ------- 65C02
                       {4'b0000, 6'b000000, push,      aluInA,   aluInp}, // 48 PHA
                       {4'b1000, 6'b100010, immediate, aluInT,   aluEor}, // 49 EOR imm
                       {4'b1000, 6'b100011, implied,   aluInA,   aluLsr}, // 4A LSR accu -------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 4B NOP ------- 65C02
                       {4'b0000, 6'b000000, jumpAbs,   aluInXXX, aluXXX}, // 4C JMP abs
                       {4'b1000, 6'b100010, readAbs,   aluInT,   aluEor}, // 4D EOR abs
                       {4'b0000, 6'b100011, rmwAbs,    aluInT,   aluLsr}, // 4E LSR abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 4F NOP ------- 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // 50 BVC
                       {4'b1000, 6'b100010, readIndY,  aluInT,   aluEor}, // 51 EOR (zp),y
                       {4'b1000, 6'b100010, readInd,   aluInT,   aluEor}, // 52 EOR (zp) -------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 53 NOP ------- 65C02
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // 54 NOP ------- 65C02
                       {4'b1000, 6'b100010, readZpX,   aluInT,   aluEor}, // 55 EOR zp,x
                       {4'b0000, 6'b100011, rmwZpX,    aluInT,   aluLsr}, // 56 LSR zp,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 57 NOP ------- 65C02
                       {4'b0000, 6'b000100, implied,   aluInClr, aluXXX}, // 58 CLI
                       {4'b1000, 6'b100010, readAbsY,  aluInT,   aluEor}, // 59 EOR abs,y
                       {4'b0000, 6'b000000, push,      aluInY,   aluInp}, // 5A PHY ------------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 5B NOP ------- 65C02
                       {4'b0000, 6'b000000, readAbs,   aluInXXX, aluXXX}, // 5C NOP ------- 65C02
                       {4'b1000, 6'b100010, readAbsX,  aluInT,   aluEor}, // 5D EOR abs,x
                       {4'b0000, 6'b100011, rmwAbsX,   aluInT,   aluLsr}, // 5E LSR abs,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 5F NOP ------- 65C02
                       // AXYS     NVDIZC    addressing  aluInput  aluMode
                       {4'b0000, 6'b000000, rts,       aluInXXX, aluXXX}, // 60 RTS
                       {4'b1000, 6'b110011, readIndX,  aluInT,   aluAdc}, // 61 ADC (zp,x)
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // 62 NOP ------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 63 NOP ------- 65C02
                       {4'b0000, 6'b000000, writeZp,   aluInClr, aluInp}, // 64 STZ zp ---------- 65C02
                       {4'b1000, 6'b110011, readZp,    aluInT,   aluAdc}, // 65 ADC zp
                       {4'b0000, 6'b100011, rmwZp,     aluInT,   aluRor}, // 66 ROR zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 67 NOP ------- 65C02
                       {4'b1000, 6'b100010, pop,       aluInT,   aluInp}, // 68 PLA
                       {4'b1000, 6'b110011, immediate, aluInT,   aluAdc}, // 69 ADC imm
                       {4'b1000, 6'b100011, implied,   aluInA,   aluRor}, // 6A ROR accu
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 6B NOP ------ 65C02
                       {4'b0000, 6'b000000, jumpInd,   aluInXXX, aluXXX}, // 6C JMP indirect
                       {4'b1000, 6'b110011, readAbs,   aluInT,   aluAdc}, // 6D ADC abs
                       {4'b0000, 6'b100011, rmwAbs,    aluInT,   aluRor}, // 6E ROR abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 6F NOP ------ 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // 70 BVS
                       {4'b1000, 6'b110011, readIndY,  aluInT,   aluAdc}, // 71 ADC (zp),y
                       {4'b1000, 6'b110011, readInd,   aluInT,   aluAdc}, // 72 ADC (zp) -------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 73 NOP ------ 65C02
                       {4'b0000, 6'b000000, writeZpX,  aluInClr, aluInp}, // 74 STZ zp,x -------- 65C02
                       {4'b1000, 6'b110011, readZpX,   aluInT,   aluAdc}, // 75 ADC zp,x
                       {4'b0000, 6'b100011, rmwZpX,    aluInT,   aluRor}, // 76 ROR zp,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 77 NOP ----- 65C02
                       {4'b0000, 6'b000100, implied,   aluInSet, aluXXX}, // 78 SEI
                       {4'b1000, 6'b110011, readAbsY,  aluInT,   aluAdc}, // 79 ADC abs,y
                       {4'b0010, 6'b100010, pop,       aluInT,   aluInp}, // 7A PLY ------------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 7B NOP ----- 65C02
                       {4'b0000, 6'b000000, jumpIndX,  aluInXXX, aluXXX}, // 7C JMP indirect,x -- 65C02
                       //{4'b0000, 6'b000000, jumpInd,   aluInXXX, aluXXX}, // 6C JMP indirect
                       {4'b1000, 6'b110011, readAbsX,  aluInT,   aluAdc}, // 7D ADC abs,x
                       {4'b0000, 6'b100011, rmwAbsX,   aluInT,   aluRor}, // 7E ROR abs,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 7F NOP ----- 65C02
                       // AXYS     NVDIZC    addressing  aluInput  aluMode
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // 80 BRA ----------- 65C02
                       {4'b0000, 6'b000000, writeIndX, aluInA,   aluInp}, // 81 STA (zp,x)
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // 82 NOP ----- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 83 NOP ----- 65C02
                       {4'b0000, 6'b000000, writeZp,   aluInY,   aluInp}, // 84 STY zp
                       {4'b0000, 6'b000000, writeZp,   aluInA,   aluInp}, // 85 STA zp
                       {4'b0000, 6'b000000, writeZp,   aluInX,   aluInp}, // 86 STX zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 87 NOP ----- 65C02
                       {4'b0010, 6'b100010, implied,   aluInY,   aluDec}, // 88 DEY
                       {4'b0000, 6'b000010, immediate, aluInT,   aluBit}, // 89 BIT imm ------- 65C02
                       {4'b1000, 6'b100010, implied,   aluInX,   aluInp}, // 8A TXA
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 8B NOP ----- 65C02
                       {4'b0000, 6'b000000, writeAbs,  aluInY,   aluInp}, // 8C STY abs ------- 65C02
                       {4'b0000, 6'b000000, writeAbs,  aluInA,   aluInp}, // 8D STA abs
                       {4'b0000, 6'b000000, writeAbs,  aluInX,   aluInp}, // 8E STX abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 8F NOP ----- 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // 90 BCC
                       {4'b0000, 6'b000000, writeIndY, aluInA,   aluInp}, // 91 STA (zp),y
                       {4'b0000, 6'b000000, writeInd,  aluInA,   aluInp}, // 92 STA (zp) ------ 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 93 NOP ----- 65C02
                       {4'b0000, 6'b000000, writeZpX,  aluInY,   aluInp}, // 94 STY zp,x
                       {4'b0000, 6'b000000, writeZpX,  aluInA,   aluInp}, // 95 STA zp,x
                       {4'b0000, 6'b000000, writeZpY,  aluInX,   aluInp}, // 96 STX zp,y
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 97 NOP ----- 65C02
                       {4'b1000, 6'b100010, implied,   aluInY,   aluInp}, // 98 TYA
                       {4'b0000, 6'b000000, writeAbsY, aluInA,   aluInp}, // 99 STA abs,y
                       {4'b0001, 6'b000000, implied,   aluInX,   aluInp}, // 9A TXS
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 9B NOP ----- 65C02
                       {4'b0000, 6'b000000, writeAbs,  aluInClr, aluInp}, // 9C STZ Abs ------- 65C02
                       {4'b0000, 6'b000000, writeAbsX, aluInA,   aluInp}, // 9D STA abs,x
                       {4'b0000, 6'b000000, writeAbsX, aluInClr, aluInp}, // 9C STZ Abs,x ----- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // 9F NOP ----- 65C02
                       // AXYS     NVDIZC    addressing  aluInput  aluMode
                       {4'b0010, 6'b100010, immediate, aluInT,   aluInp}, // A0 LDY imm
                       {4'b1000, 6'b100010, readIndX,  aluInT,   aluInp}, // A1 LDA (zp,x)
                       {4'b0100, 6'b100010, immediate, aluInT,   aluInp}, // A2 LDX imm
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // A3 NOP ----- 65C02
                       {4'b0010, 6'b100010, readZp,    aluInT,   aluInp}, // A4 LDY zp
                       {4'b1000, 6'b100010, readZp,    aluInT,   aluInp}, // A5 LDA zp
                       {4'b0100, 6'b100010, readZp,    aluInT,   aluInp}, // A6 LDX zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // A7 NOP ----- 65C02
                       {4'b0010, 6'b100010, implied,   aluInA,   aluInp}, // A8 TAY
                       {4'b1000, 6'b100010, immediate, aluInT,   aluInp}, // A9 LDA imm
                       {4'b0100, 6'b100010, implied,   aluInA,   aluInp}, // AA TAX
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // AB NOP ----- 65C02
                       {4'b0010, 6'b100010, readAbs,   aluInT,   aluInp}, // AC LDY abs
                       {4'b1000, 6'b100010, readAbs,   aluInT,   aluInp}, // AD LDA abs
                       {4'b0100, 6'b100010, readAbs,   aluInT,   aluInp}, // AE LDX abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // AF NOP ----- 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // B0 BCS
                       {4'b1000, 6'b100010, readIndY,  aluInT,   aluInp}, // B1 LDA (zp),y
                       {4'b1000, 6'b100010, readInd,   aluInT,   aluInp}, // B2 LDA (zp) ------ 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // B3 NOP ----- 65C02
                       {4'b0010, 6'b100010, readZpX,   aluInT,   aluInp}, // B4 LDY zp,x
                       {4'b1000, 6'b100010, readZpX,   aluInT,   aluInp}, // B5 LDA zp,x
                       {4'b0100, 6'b100010, readZpY,   aluInT,   aluInp}, // B6 LDX zp,y
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // B7 NOP ----- 65C02
                       {4'b0000, 6'b010000, implied,   aluInClr, aluFlg}, // B8 CLV
                       {4'b1000, 6'b100010, readAbsY,  aluInT,   aluInp}, // B9 LDA abs,y
                       {4'b0100, 6'b100010, implied,   aluInS,   aluInp}, // BA TSX
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // BB NOP ----- 65C02
                       {4'b0010, 6'b100010, readAbsX,  aluInT,   aluInp}, // BC LDY abs,x
                       {4'b1000, 6'b100010, readAbsX,  aluInT,   aluInp}, // BD LDA abs,x
                       {4'b0100, 6'b100010, readAbsY,  aluInT,   aluInp}, // BE LDX abs,y
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // BF NOP ----- 65C02
                       // AXYS     NVDIZC    addressing  aluInput  aluMode
                       {4'b0000, 6'b100011, immediate, aluInT,   aluCpy}, // C0 CPY imm
                       {4'b0000, 6'b100011, readIndX,  aluInT,   aluCmp}, // C1 CMP (zp,x)
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // C2 NOP ----- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // C3 NOP ----- 65C02
                       {4'b0000, 6'b100011, readZp,    aluInT,   aluCpy}, // C4 CPY zp
                       {4'b0000, 6'b100011, readZp,    aluInT,   aluCmp}, // C5 CMP zp
                       {4'b0000, 6'b100010, rmwZp,     aluInT,   aluDec}, // C6 DEC zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // C7 NOP ----- 65C02
                       {4'b0010, 6'b100010, implied,   aluInY,   aluInc}, // C8 INY
                       {4'b0000, 6'b100011, immediate, aluInT,   aluCmp}, // C9 CMP imm
                       {4'b0100, 6'b100010, implied,   aluInX,   aluDec}, // CA DEX
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // CB NOP ----- 65C02
                       {4'b0000, 6'b100011, readAbs,   aluInT,   aluCpy}, // CC CPY abs
                       {4'b0000, 6'b100011, readAbs,   aluInT,   aluCmp}, // CD CMP abs
                       {4'b0000, 6'b100010, rmwAbs,    aluInT,   aluDec}, // CE DEC abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // CF NOP ----- 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // D0 BNE
                       {4'b0000, 6'b100011, readIndY,  aluInT,   aluCmp}, // D1 CMP (zp),y
                       {4'b0000, 6'b100011, readInd,   aluInT,   aluCmp}, // D2 CMP (zp) ------ 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // D3 NOP ----- 65C02
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // D4 NOP ----- 65C02
                       {4'b0000, 6'b100011, readZpX,   aluInT,   aluCmp}, // D5 CMP zp,x
                       {4'b0000, 6'b100010, rmwZpX,    aluInT,   aluDec}, // D6 DEC zp,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // D7 NOP ----- 65C02
                       {4'b0000, 6'b001000, implied,   aluInClr, aluXXX}, // D8 CLD
                       {4'b0000, 6'b100011, readAbsY,  aluInT,   aluCmp}, // D9 CMP abs,y
                       {4'b0000, 6'b000000, push,      aluInX,   aluInp}, // DA PHX ----------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // DB NOP ----- 65C02
                       {4'b0000, 6'b000000, readAbs,   aluInXXX, aluXXX}, // DC NOP ----- 65C02
                       {4'b0000, 6'b100011, readAbsX,  aluInT,   aluCmp}, // DD CMP abs,x
                       {4'b0000, 6'b100010, rmwAbsX,   aluInT,   aluDec}, // DE DEC abs,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // DF NOP ----- 65C02
                       // AXYS    NVDIZC    addressing  aluInput  aluMode
                       {4'b0000, 6'b100011, immediate, aluInT,   aluCpx}, // E0 CPX imm
                       {4'b1000, 6'b110011, readIndX,  aluInT,   aluSbc}, // E1 SBC (zp,x)
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // E2 NOP ----- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // E3 NOP ----- 65C02
                       {4'b0000, 6'b100011, readZp,    aluInT,   aluCpx}, // E4 CPX zp
                       {4'b1000, 6'b110011, readZp,    aluInT,   aluSbc}, // E5 SBC zp
                       {4'b0000, 6'b100010, rmwZp,     aluInT,   aluInc}, // E6 INC zp
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // E7 NOP ----- 65C02
                       {4'b0100, 6'b100010, implied,   aluInX,   aluInc}, // E8 INX
                       {4'b1000, 6'b110011, immediate, aluInT,   aluSbc}, // E9 SBC imm
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // EA NOP
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // EB NOP ----- 65C02
                       {4'b0000, 6'b100011, readAbs,   aluInT,   aluCpx}, // EC CPX abs
                       {4'b1000, 6'b110011, readAbs,   aluInT,   aluSbc}, // ED SBC abs
                       {4'b0000, 6'b100010, rmwAbs,    aluInT,   aluInc}, // EE INC abs
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // EF NOP ----- 65C02
                       {4'b0000, 6'b000000, relative,  aluInXXX, aluXXX}, // F0 BEQ
                       {4'b1000, 6'b110011, readIndY,  aluInT,   aluSbc}, // F1 SBC (zp),y
                       {4'b1000, 6'b110011, readInd,   aluInT,   aluSbc}, // F2 SBC (zp) ------ 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // F3 NOP ----- 65C02
                       {4'b0000, 6'b000000, immediate, aluInXXX, aluXXX}, // F4 NOP ----- 65C02
                       {4'b1000, 6'b110011, readZpX,   aluInT,   aluSbc}, // F5 SBC zp,x
                       {4'b0000, 6'b100010, rmwZpX,    aluInT,   aluInc}, // F6 INC zp,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // F7 NOP  ---- 65C02
                       {4'b0000, 6'b001000, implied,   aluInSet, aluXXX}, // F8 SED
                       {4'b1000, 6'b110011, readAbsY,  aluInT,   aluSbc}, // F9 SBC abs,y
                       {4'b0100, 6'b100010, pop,       aluInT,   aluInp}, // FA PLX ----------- 65C02
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}, // FB NOP ----- 65C02
                       {4'b0000, 6'b000000, readAbs,   aluInXXX, aluXXX}, // FC NOP ----- 65C02
                       {4'b1000, 6'b110011, readAbsX,  aluInT,   aluSbc}, // FD SBC abs,x
                       {4'b0000, 6'b100010, rmwAbsX,   aluInT,   aluInc}, // FE INC abs,x
                       {4'b0000, 6'b000000, implied,   aluInXXX, aluXXX}  // FF NOP ----- 65C02
                       };
  logic [0:43]       opcInfo;
  logic [0:43]       nextOpcInfo;	// Next opcode (decoded)
  logic [0:43]       nextOpcInfoReg;	// Next opcode (decoded) pipelined
  logic [7:0]        theOpcode;
  logic [7:0]        nextOpcode;

  // Program counter
  logic [15:0]       PC; // Program counter

  // Address generation
  typedef enum bit [3:0]
               {
                nextAddrHold,
                nextAddrIncr,
                nextAddrIncrL, // Increment low bits only (zeropage accesses)
                nextAddrIncrH, // Increment high bits only (page-boundary)
                nextAddrDecrH, // Decrement high bits (branch backwards)
                nextAddrPc,
                nextAddrIrq,
                nextAddrReset,
                nextAddrAbs,
                nextAddrAbsIndexed,
                nextAddrZeroPage,
                nextAddrZPIndexed,
                nextAddrStack,
                nextAddrRelative
                } nextAddrDef_t;

  nextAddrDef_t nextAddr;

  logic [15:0] myAddr;
  logic [15:0] myAddrIncr;
  logic [7:0]  myAddrIncrH;
  logic [7:0]  myAddrDecrH;
  logic        irqActive;
  // Buffer register
  logic [7:0]  T;
  // General registers
  logic [7:0]  A; // Accumulator
  logic [7:0]  X; // Index X
  logic [7:0]  Y; // Index Y
  logic [7:0]  S; // stack pointer
  // Status register
  logic        C; // Carry
  logic        Z; // Zero flag
  logic        I; // Interrupt flag
  logic        D; // Decimal mode
  logic        B; // Break software interrupt
  logic        R; // always 1
  logic        V; // Overflow
  logic        N; // Negative

  // ALU
  // ALU input
  logic [7:0]  aluInput;
  logic [7:0]  aluCmpInput;
  // ALU output
  logic [7:0]  aluRegisterOut;
  logic [7:0]  aluRmwOut;
  logic        aluC;
  logic        aluZ;
  logic        aluV;
  logic        aluN;
  // Indexing
  logic [8:0]  indexOut;

  logic        realbrk;

  always_comb begin
    logic [7:0] temp;
    temp = '1;
    if (opcInfo[opcInA])     temp = temp & A;
    if (opcInfo[opcInX])     temp = temp & X;
    if (opcInfo[opcInY])     temp = temp & Y;
    if (opcInfo[opcInS])     temp = temp & S;
    if (opcInfo[opcInT])     temp = temp & T;
    if (opcInfo[opcInBrk])   temp = temp & 8'b11100111; // also DMB clear D (bit 3)
    if (opcInfo[opcInClear]) temp = '0;
    aluInput = temp;
  end // always_comb

  always_comb begin
    logic [7:0] temp;
    temp = '1;
    if (opcInfo[opcInCmp]) temp = temp & A;
    if (opcInfo[opcInCpx]) temp = temp & X;
    if (opcInfo[opcInCpy]) temp = temp & Y;
    aluCmpInput = temp;
  end

  // ALU consists of two parts
  // Read-Modify-Write or index instructions: INC/DEC/ASL/LSR/ROR/ROL
  // Accumulator instructions: ADC, SBC, EOR, AND, EOR, ORA
  // Some instructions are both RMW and accumulator so for most
  // instructions the rmw results are routed through accu alu too.

  //	The B flag
  //------------
  //No actual "B" flag exists inside the 6502's processor status register. The B
  //flag only exists in the status flag byte pushed to the stack. Naturally,
  //when the flags are restored (via PLP or RTI), the B bit is discarded.
  //
  //Depending on the means, the B status flag will be pushed to the stack as
  //either 0 or 1.
  //
  //software instructions BRK & PHP will push the B flag as being 1.
  //hardware interrupts IRQ & NMI will push the B flag as being 0.
  always_comb begin
    logic [5:0] lowBits;
    logic [8:0] nineBits;
    logic [8:0] rmwBits;
    logic [8:0] tsxBits;

    logic       varC;
    logic       varZ;
    logic       varV;
    logic       varN;

    lowBits  = 'x;
    nineBits = 'x;
    rmwBits  = 'x;
    tsxBits  = 'x;
    R        = '1;

    // Shift unit
    case (opcInfo[aluMode1From:aluMode1To])
      aluModeInp: rmwBits = {C, aluInput};
      aluModeP:   rmwBits = {C, N, V, R, ~irqActive, D, I, Z, C}; // irqActive
      aluModeInc: rmwBits = {C, 8'(aluInput + 1'b1)};
      aluModeDec: rmwBits = {C, 8'(aluInput - 1'b1)};
      aluModeAsl: rmwBits = {aluInput, 1'b0};
      aluModeTSB: begin
        rmwBits = {1'b0, (aluInput[7:0] | A)};			// added by alan for 65c02
        tsxBits = {1'b0, (aluInput[7:0] & A)};
      end
      aluModeTRB: begin
        rmwBits = {1'b0, (aluInput[7:0] & ~A)};                 // added by alan for 65c02
        tsxBits = {1'b0, (aluInput[7:0] &  A)};
      end
      aluModeFlg: rmwBits = {aluInput[0], aluInput};
      aluModeLsr: rmwBits = {aluInput[0], 1'b0, aluInput[7:1]};
      aluModeRol: rmwBits = {aluInput, C};
      aluModeRor: rmwBits = {aluInput[0], C, aluInput[7:1]};
      default:    rmwBits = {C, aluInput};
    endcase

    // ALU
    case (opcInfo[aluMode2From:aluMode2To])
      aluModeAdc: begin
        lowBits  = {1'b0, A[3:0], rmwBits[8]} + {1'b0, rmwBits[3:0], 1'b1};
        nineBits = {1'b0, A}                  + {1'b0, rmwBits[7:0]}        + {8'b0, rmwBits[8]};
      end
      aluModeSbc: begin
        lowBits  = {1'b0, A[3:0], rmwBits[8]} + {1'b0, ~rmwBits[3:0], 1'b1};
        nineBits = {1'b0, A}                  + {1'b0, ~rmwBits[7:0]}       + {8'b0, rmwBits[8]};
      end
      aluModeCmp: nineBits = {1'b0, aluCmpInput} + {1'b0, ~rmwBits[7:0]} + 9'b1;
      aluModeAnd: nineBits = {rmwBits[8], (A & rmwBits[7:0])};
      aluModeEor: nineBits = {rmwBits[8], (A ^ rmwBits[7:0])};
      aluModeOra: nineBits = {rmwBits[8], (A | rmwBits[7:0])};
      aluModeNoF: nineBits = 9'b000110000;
      default:	  nineBits = rmwBits;
    endcase

    varV = aluInput[6]; // Default for BIT / PLP / RTI

    if (opcInfo[aluMode1From:aluMode1To] == aluModeFlg) begin
      varZ = rmwBits[1];
    end else if ((opcInfo[aluMode1From:aluMode1To] == aluModeTSB) ||
                 (opcInfo[aluMode1From:aluMode1To] == aluModeTRB)) begin
      varZ = ~|tsxBits[7:0];
    end else begin
      varZ = ~|nineBits[7:0];
    end

    if ((opcInfo[aluMode1From:aluMode1To] == aluModeBit) ||
        (opcInfo[aluMode1From:aluMode1To] == aluModeFlg)) begin
      varN = rmwBits[7];
    end else begin
      varN = nineBits[7];
    end

    varC = nineBits[8];

    case (opcInfo[aluMode2From:aluMode2To])
      //		Flags Affected: n v — — — — z c
      //		n Set if most significant bit of result is set; else cleared.
      //		v Set if signed overflow; cleared if valid signed result.
      //		z Set if result is zero; else cleared.
      //		c Set if unsigned overflow; cleared if valid unsigned result

      aluModeAdc: begin
        // decimal mode low bits correction, is done after setting Z flag.
        if (D) begin
          if (lowBits[5:1] > 9) begin
            nineBits[3:0] = nineBits[3:0] + 4'd6;
            if (~lowBits[5]) begin
              nineBits[8:4] = nineBits[8:4] + 1'b1;
            end
          end
        end
      end
    endcase

    case (opcInfo[aluMode2From:aluMode2To])
      aluModeAdc: begin
        // decimal mode high bits correction, is done after setting Z and N flags
        varV = (A[7] ^ nineBits[7]) & (rmwBits[7] ^ nineBits[7]);
        if (D) begin
          if (nineBits[8:4] > 9) begin
            nineBits[8:4] = nineBits[8:4] + 5'd6;
            varC = '1;
          end
        end
      end

      aluModeSbc: begin
        varV = (A[7] ^ nineBits[7]) & (~rmwBits[7] ^ nineBits[7]);
        if (D) begin
          // Check for borrow (lower 4 bits)
          if (~lowBits[5]) begin
            nineBits[7:0] = nineBits[7:0] - 8'd6;
          end
          // Check for borrow (upper 4 bits)
          if (~nineBits[8]) begin
            nineBits[8:4] = nineBits[8:4] - 5'd6;
          end
        end
      end
    endcase

    // fix n and z flag for 65c02 adc sbc instructions in decimal mode
    case (opcInfo[aluMode2From:aluMode2To])
      aluModeAdc, aluModeSbc: begin
        if (D) begin
          varZ = ~|nineBits[7:0];
          varN = nineBits[7];
        end
      end
    endcase

    // DMB Remove Pipelining
    //	if rising_edge(clk) then
    aluRmwOut = rmwBits[7:0];
    aluRegisterOut = nineBits[7:0];
    aluC = varC;
    aluZ = varZ;
    aluV = varV;
    aluN = varN;
    // end if;
  end // always_comb

  always_ff @(posedge clk) begin : calcInterrupt
    if (enable) begin
      if ((theCpuCycle == cycleStack4) || ~reset) begin
        nmiReg <= '1;
      end
      if ((nextCpuCycle != cycleBranchTaken) &&
          (nextCpuCycle != opcodeFetch)) begin
        irqReg <= irq_n;
        nmiEdge <= nmi_n;
        if (nmiEdge && ~nmi_n) begin
          nmiReg <= '0;
        end
      end
      // The 'or opcInfo(opcSetI)' prevents NMI immediately after BRK or IRQ.
      // Presumably this is done in the real 6502/6510 to prevent a double IRQ.
      processIrq <= ~((nmiReg & (irqReg | I)) | opcInfo[opcIRQ]);
    end
  end  : calcInterrupt

  //pipeirq: process(clk)
  //	begin
  //		if rising_edge(clk) then
  //			if enable = '1' then
  //				if (reset = '0') or (theCpuCycle = opcodeFetch) then
  //                    // The 'or opcInfo(opcSetI)' prevents NMI immediately after BRK or IRQ.
  //                    // Presumably this is done in the real 6502/6510 to prevent a double IRQ.
  //                    processIrq <= not ((nmiReg and (irqReg or I)) or opcInfo(opcIRQ));
  //				end if;
  //			end if;
  //		end if;
  //	end process;

  always_comb begin : calcNextOpcode
    logic [7:0] myNextOpcode;
    // Next opcode is read from input unless a reset or IRQ is pending.
    myNextOpcode = di;

    if (~reset) begin
      myNextOpcode = 8'h4C;
    end else if (processIrq) begin
      myNextOpcode = '0;
    end
    nextOpcode = myNextOpcode;
  end : calcNextOpcode

  assign nextOpcInfo = opcodeInfoTable[nextOpcode];

  // DMB Remove Pipelining
  //	process(clk)
  //	begin
  //		if rising_edge(clk) then
  assign nextOpcInfoReg = nextOpcInfo;
  //		end if;
  //	end process;

  // Read bits and flags from opcodeInfoTable and store in opcInfo.
  // This info is used to control the execution of the opcode.
  always_ff @(posedge clk) begin : calcOpcInfo
    if (enable) begin
      if (~reset || (theCpuCycle == opcodeFetch)) begin
        opcInfo <= nextOpcInfo;
      end
    end
  end : calcOpcInfo

  always_ff @(posedge clk) begin : calcTheOpcode
    if (enable) begin
      if (theCpuCycle == opcodeFetch) begin
        irqActive <= '0;
        if (processIrq) begin
          irqActive <= '1;
        end
        // Fetch opcode
        theOpcode <= nextOpcode;
      end
    end
  end : calcTheOpcode

  // -----------------------------------------------------------------------
  // State machine
  // -----------------------------------------------------------------------
  always_comb begin
    updateRegisters = '0;
    if (enable) begin
      if (opcInfo[opcRti]) begin
        if (theCpuCycle == cycleRead) begin
          updateRegisters = '1;
        end
      end else if (theCpuCycle == opcodeFetch) begin
        updateRegisters = '1;
      end
    end
  end

  always_ff @(posedge clk) begin
    if (enable) begin
      theCpuCycle <= nextCpuCycle;
    end
    if (~reset) begin
      theCpuCycle <= cycle2;
    end
  end

  // Determine the next cpu cycle. After the last cycle we always
  // go to opcodeFetch to get the next opcode.
  always_comb begin : calcNextCpuCycle
    nextCpuCycle = opcodeFetch;

    case (theCpuCycle)
      opcodeFetch: nextCpuCycle = cycle2;
      cycle2: begin
        if (opcInfo[opcBranch]) begin
          if ((N == theOpcode[5] && (theOpcode[7:6] == 2'b00)) ||
              (V == theOpcode[5] && (theOpcode[7:6] == 2'b01)) ||
              (C == theOpcode[5] && (theOpcode[7:6] == 2'b10)) ||
              (Z == theOpcode[5] && (theOpcode[7:6] == 2'b11)) ||
              (theOpcode[7:0] == 8'h80)) begin // Branch condition is true
            nextCpuCycle           = cycleBranchTaken;
          end
        end else if (opcInfo[opcStackUp]) begin
          nextCpuCycle = cycleStack1;
        end else if (opcInfo[opcStackAddr] && opcInfo[opcStackData]) begin
          nextCpuCycle = cycleStack2;
        end else if (opcInfo[opcStackAddr]) begin
          nextCpuCycle = cycleStack1;
        end else if (opcInfo[opcStackData]) begin
          nextCpuCycle = cycleWrite;
        end else if (opcInfo[opcAbsolute]) begin
          nextCpuCycle = cycle3;
        end else if (opcInfo[opcIndirect]) begin
          if (opcInfo[indexX]) begin
            nextCpuCycle = cyclePreIndirect;
          end else begin
            nextCpuCycle = cycleIndirect;
          end
        end else if (opcInfo[opcZeroPage]) begin
          if (opcInfo[opcWrite]) begin
            if (opcInfo[indexX] || opcInfo[indexY]) begin
              nextCpuCycle = cyclePreWrite;
            end else begin
              nextCpuCycle = cycleWrite;
            end
          end else begin
            if (opcInfo[indexX] || opcInfo[indexY]) begin
              nextCpuCycle = cyclePreRead;
            end else begin
              nextCpuCycle = cycleRead2;
            end
          end
        end else if (opcInfo[opcJump]) begin
          nextCpuCycle = cycleJump;
        end
      end
      cycle3: begin
        nextCpuCycle = cycleRead;
        if (opcInfo[opcWrite]) begin
          if (opcInfo[indexX] || opcInfo[indexY]) begin
            nextCpuCycle = cyclePreWrite;
          end else begin
            nextCpuCycle = cycleWrite;
          end
        end
        if (opcInfo[opcIndirect] && opcInfo[indexX]) begin
          if (opcInfo[opcWrite]) begin
            nextCpuCycle = cycleWrite;
          end else begin
            nextCpuCycle = cycleRead2;
          end
        end
      end
      cyclePreIndirect: nextCpuCycle = cycleIndirect;
      cycleIndirect: nextCpuCycle = cycle3;
      cycleBranchTaken: begin
        if (indexOut[8] != T[7]) begin
          nextCpuCycle = cycleBranchPage;
        end
      end
      cyclePreRead: begin
        if (opcInfo[opcZeroPage]) begin
          nextCpuCycle = cycleRead2;
        end
      end
      cycleRead: begin
        if (opcInfo[opcJump]) begin
          nextCpuCycle = cycleJump;
        end else if (indexOut[8]) begin
          nextCpuCycle = cycleRead2;
        end else if (opcInfo[opcRmw]) begin
          nextCpuCycle = cycleRmw;
          if (opcInfo[indexX] || opcInfo[indexY]) begin
            nextCpuCycle = cycleRead2;
          end
        end
      end
      cycleRead2: begin
        if (opcInfo[opcRmw]) begin
          nextCpuCycle = cycleRmw;
        end
      end
      cycleRmw: nextCpuCycle = cycleWrite;
      cyclePreWrite: nextCpuCycle = cycleWrite;
      cycleStack1: begin
        nextCpuCycle = cycleRead;
        if (opcInfo[opcStackAddr]) begin
          nextCpuCycle = cycleStack2;
        end
      end
      cycleStack2: begin
        nextCpuCycle = cycleStack3;
        if (opcInfo[opcRti]) begin
          nextCpuCycle = cycleRead;
        end
        if (~opcInfo[opcStackData] && opcInfo[opcStackUp]) begin
          nextCpuCycle = cycleJump;
        end
      end
      cycleStack3: begin
        nextCpuCycle = cycleRead;
        if (~opcInfo[opcStackData] || opcInfo[opcStackUp]) begin
          nextCpuCycle = cycleJump;
        end else if (opcInfo[opcStackAddr]) begin
          nextCpuCycle = cycleStack4;
        end
      end
      cycleStack4: nextCpuCycle = cycleRead;
      cycleJump: begin
        if (opcInfo[opcIncrAfter]) begin
          nextCpuCycle = cycleEnd;
        end
      end
    endcase // case (theCpuCycle)
  end : calcNextCpuCycle

  // -----------------------------------------------------------------------
  // T register
  // -----------------------------------------------------------------------
  always_ff @(posedge clk) begin : calcT
    if (enable) begin
      case (theCpuCycle)
        cycle2:	T <= di;
        cycleStack1, cycleStack2: begin
          if (opcInfo[opcStackUp]) begin
            if ((theOpcode == 8'h28) || (theOpcode == 8'h40)) begin  // plp or rti pulling the flags off the stack
              T <= di | 8'b00110000;                      // Read from stack
            end else begin
              T <= di;
            end
          end
        end
        cycleIndirect, cycleRead, cycleRead2: T <= di;
      endcase
    end // if (enable)
  end // block: calcT

  // Non reset registers
  always_ff @(posedge clk) begin : Registers
    if (updateRegisters) begin
      if (opcInfo[opcUpdateA]) A <= aluRegisterOut; // A register
      if (opcInfo[opcUpdateX]) X <= aluRegisterOut; // X register
      if (opcInfo[opcUpdateY]) Y <= aluRegisterOut; // Y register
      if (opcInfo[opcUpdateC]) C <= aluC;           // C Flag
      if (opcInfo[opcUpdateZ]) Z <= aluZ;           // Z Flag
      if (opcInfo[opcUpdateV]) V <= aluV;           // V Flag
      if (opcInfo[opcUpdateN]) N <= aluN;           // N Flag
    end
  end : Registers

  // Registers requiring resets
  always_ff @(posedge clk, negedge reset) begin : RstRegisters
    if (~reset) begin
      I <= '1;                                      // I flag interupt flag
      D <= '0;                                      // D flag
    end else begin
      if (updateRegisters) begin
        if (opcInfo[opcUpdateI]) I <= aluInput[2];  // I flag interupt flag
        if (opcInfo[opcUpdateD]) D <= aluInput[3];  // D flag
      end
    end
  end : RstRegisters

  // -----------------------------------------------------------------------
  // Stack pointer
  // -----------------------------------------------------------------------
  logic [7:0] sIncDec;
  always_comb begin
    if (opcInfo[opcStackUp]) sIncDec = S + 1'b1;
    else                     sIncDec = S - 1'b1;
  end

  always_ff @(posedge clk) begin
    if (enable) begin
      case (nextCpuCycle)
        cycleStack1: begin
          if (opcInfo[opcStackUp] || opcInfo[opcStackData]) begin
            S <= sIncDec;
          end
        end
        cycleStack2, cycleStack3, cycleStack4: S <= sIncDec;
        cycleRead: begin
          if (opcInfo[opcRti]) S <= sIncDec;
        end
        cycleWrite: begin
          if (opcInfo[opcStackData]) S <= sIncDec;
        end
      endcase
    end
    if (updateRegisters)  begin
      if (opcInfo[opcUpdateS]) S <= aluRegisterOut;
    end
  end

  // -----------------------------------------------------------------------
  // Data out
  // -----------------------------------------------------------------------
  always_ff @(posedge clk) begin : calcDo
    if (enable) begin
      dout <= aluRmwOut;
      case (nextCpuCycle)
        cycleStack2: begin
          if (opcInfo[opcIRQ] && ~irqActive) begin
            dout <= myAddrIncr[15:8];
          end else begin
            dout <= PC[15:8];
          end
        end
        cycleStack3: dout <= PC[7:0];
        cycleRmw: dout <= di; // Read-modify-write write old value first.
      endcase
    end // if (enable)
  end : calcDo

  // -----------------------------------------------------------------------
  // Write enable
  // -----------------------------------------------------------------------
  always_ff @(posedge clk) begin : calcWe
    if (enable) begin
      nwe <= '1;
      case (nextCpuCycle)
        cycleStack1: begin
          if (~opcInfo[opcStackUp] && (~opcInfo[opcStackAddr] || opcInfo[opcStackData])) begin
            nwe <= '0;
          end
        end
        cycleStack2, cycleStack3, cycleStack4: begin
          if (~opcInfo[opcStackUp]) begin
            nwe <= '0;
          end
        end
        cycleRmw: nwe <= '0;
        cycleWrite: nwe <= '0;
      endcase
    end // if (enable)
  end : calcWe

  // -----------------------------------------------------------------------
  // Program counter
  // -----------------------------------------------------------------------
  always_ff @(posedge clk) begin : calcPC
    if (enable) begin
      case (theCpuCycle)
        opcodeFetch: PC <= myAddr;
        cycle2: begin
          if (~irqActive) begin
            if (opcInfo[opcSecondByte]) begin
              PC <= myAddrIncr;
            end else begin
              PC <= myAddr;
            end
          end
        end
        cycle3: begin
          if (opcInfo[opcAbsolute]) begin
            PC <= myAddrIncr;
          end
        end
      endcase
    end // if (enable)
  end : calcPC

  // -----------------------------------------------------------------------
  // Address generation
  // -----------------------------------------------------------------------
  always_comb begin : calcNextAddr
    nextAddr = nextAddrIncr;
    case (theCpuCycle)
      cycle2: begin
        if (opcInfo[opcStackAddr] || opcInfo[opcStackData]) nextAddr = nextAddrStack;
        else if (opcInfo[opcAbsolute])                      nextAddr = nextAddrIncr;
        else if (opcInfo[opcZeroPage])                      nextAddr = nextAddrZeroPage;
        else if (opcInfo[opcIndirect])                      nextAddr = nextAddrZeroPage;
        else if (opcInfo[opcSecondByte])                    nextAddr = nextAddrIncr;
        else                                                nextAddr = nextAddrHold;
      end
      cycle3: begin
        if (opcInfo[opcIndirect] && opcInfo[indexX]) begin
          nextAddr = nextAddrAbs;
        end else begin
          nextAddr = nextAddrAbsIndexed;
        end
      end
      cyclePreIndirect:                                     nextAddr = nextAddrZPIndexed;
      cycleIndirect:                                        nextAddr = nextAddrIncrL;
      cycleBranchTaken:                                     nextAddr = nextAddrRelative;
      cycleBranchPage: begin
        if (~T[7]) begin
          nextAddr = nextAddrIncrH;
        end else begin
          nextAddr = nextAddrDecrH;
        end
      end
      cyclePreRead:                                         nextAddr = nextAddrZPIndexed;
      cycleRead: begin
        nextAddr = nextAddrPc;
        if (opcInfo[opcJump]) begin
          // Emulate 6510 bug, jmp(xxFF) fetches from same page.
          // Replace with nextAddrIncr if emulating 65C02 or later cpu.
          nextAddr = nextAddrIncr;
          //nextAddr = nextAddrIncrL;
        end else if (indexOut[8]) begin
          nextAddr = nextAddrIncrH;
        end else if (opcInfo[opcRmw]) begin
          nextAddr = nextAddrHold;
        end
      end
      cycleRead2: begin
        nextAddr = nextAddrPc;
        if (opcInfo[opcRmw]) begin
          nextAddr = nextAddrHold;
        end
      end
      cycleRmw:                                             nextAddr = nextAddrHold;
      cyclePreWrite: begin
        nextAddr = nextAddrHold;
        if (opcInfo[opcZeroPage]) begin
          nextAddr = nextAddrZPIndexed;
        end else if (indexOut[8]) begin
          nextAddr = nextAddrIncrH;
        end
      end
      cycleWrite:                                           nextAddr = nextAddrPc;
      cycleStack1:                                          nextAddr = nextAddrStack;
      cycleStack2:                                          nextAddr = nextAddrStack;
      cycleStack3: begin
        nextAddr = nextAddrStack;
        if (~opcInfo[opcStackData])                         nextAddr = nextAddrPc;
      end
      cycleStack4:                                          nextAddr = nextAddrIrq;
      cycleJump:                                            nextAddr = nextAddrAbs;
    endcase

    if (~reset)                                             nextAddr = nextAddrReset;
  end : calcNextAddr

  always_comb begin : indexAlu
    if      (opcInfo[indexX])    indexOut = {1'b0, T} + {1'b0, X};
    else if (opcInfo[indexY])    indexOut = {1'b0, T} + {1'b0, Y};
    else if (opcInfo[opcBranch]) indexOut = {1'b0, T} + {1'b0, myAddr[7:0]};
    else                         indexOut = {1'b0, T};
  end : indexAlu

  always_ff @(posedge clk) begin : calcAddr
    if (enable) begin
      case (nextAddr)
        nextAddrIncr:  myAddr       <= myAddrIncr;
        nextAddrIncrL: myAddr[7:0]  <= myAddrIncr[7:0];
        nextAddrIncrH: myAddr[15:8] <= myAddrIncrH;
        nextAddrDecrH: myAddr[15:8] <= myAddrDecrH;
        nextAddrPc:    myAddr       <= PC;
        nextAddrIrq: begin
          myAddr <= 16'hFFFE;
          if (~nmiReg) myAddr <= 16'hFFFA;
        end
        nextAddrReset: myAddr <= 16'hFFFC;
        nextAddrAbs:   myAddr <= {di, T};
        nextAddrAbsIndexed: begin
          // myAddr <= di & indexOut(7 downto 0);
          if (theOpcode == 8'h7C) myAddr <= {di, T} + {8'h00, X};
          else                    myAddr <= {di, indexOut[7:0]};
        end
        nextAddrZeroPage:  myAddr <= {8'b0, di};
        nextAddrZPIndexed: myAddr <= {8'b0, indexOut[7:0]};
        nextAddrStack:     myAddr <= {8'b1, S};
        nextAddrRelative:  myAddr[7:0] <= indexOut[7:0];
      endcase
    end
  end : calcAddr

  assign myAddrIncr  = myAddr + 1'b1;
  assign myAddrIncrH = myAddr[15:8] + 1'b1;
  assign myAddrDecrH = myAddr[15:8] - 1'b1;
  assign addr        = myAddr;

  // DMB This looked plain broken and inferred a latch
  //
  //	calcsync: process(clk)
  //	begin
  //
  //			if enable = '1' then
  //				case theCpuCycle is
  //				when opcodeFetch =>			sync <= '1';
  //				when others =>					sync <= '0';
  //				end case;
  //			end if;
  //	end process;

  assign sync = (theCpuCycle == opcodeFetch);

  assign sync_irq = irqActive;

  assign Regs = {PC,
                 8'b00000001, S,
                 N, V, R, B, D, I, Z, C,
                 Y,
                 X,
                 A};

endmodule // R65C02
