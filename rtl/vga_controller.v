module vga_controller
  (input  CLK_14M,
   input  VIDEO,
   input  COLOR_LINE,
   input  [1:0] SCREEN_MODE,
   input  HBL,
   input  VBL,
   output VGA_HS,
   output VGA_VS,
   output VGA_HBL,
   output VGA_VBL,
   output [7:0] VGA_R,
   output [7:0] VGA_G,
   output [7:0] VGA_B);
  wire [5:0] shift_reg;
  wire last_hbl;
  wire [10:0] hcount;
  wire [5:0] vcount;
  wire vbl_delayed;
  wire [17:0] de_delayed;
  wire n10_o;
  wire n11_o;
  wire [5:0] n13_o;
  wire [5:0] n15_o;
  wire [10:0] n17_o;
  wire [10:0] n19_o;
  reg n27_q;
  reg [10:0] n28_q;
  wire [5:0] n29_o;
  reg [5:0] n30_q;
  wire n31_o;
  reg n32_q;
  wire n37_o;
  wire n39_o;
  wire n41_o;
  wire n43_o;
  wire n45_o;
  wire n47_o;
  wire n49_o;
  wire n51_o;
  reg n56_q;
  wire n57_o;
  reg n58_q;
  wire [4:0] n65_o;
  wire [5:0] n66_o;
  wire n68_o;
  wire n70_o;
  wire n72_o;
  wire n74_o;
  wire [3:0] n75_o;
  reg [7:0] n81_o;
  reg [7:0] n88_o;
  reg [7:0] n95_o;
  wire n97_o;
  wire n98_o;
  wire n100_o;
  wire n102_o;
  wire n104_o;
  wire n106_o;
  wire [3:0] n107_o;
  reg [7:0] n113_o;
  reg [7:0] n119_o;
  reg [7:0] n125_o;
  wire [7:0] n126_o;
  wire [7:0] n127_o;
  wire [7:0] n128_o;
  wire n129_o;
  wire n130_o;
  wire n131_o;
  wire n132_o;
  wire n133_o;
  wire n134_o;
  wire n135_o;
  wire n136_o;
  wire [10:0] n138_o;
  wire [1:0] n140_o;
  wire [1:0] n142_o;
  localparam [31:0] n144_o = 32'b10001000001110000000011100111000;
  wire [7:0] n146_o;
  wire [10:0] n148_o;
  wire [1:0] n150_o;
  wire [1:0] n152_o;
  localparam [31:0] n154_o = 32'b00100010001001000110011101010010;
  wire [7:0] n156_o;
  wire [10:0] n158_o;
  wire [1:0] n160_o;
  wire [1:0] n162_o;
  localparam [31:0] n164_o = 32'b00101100101000000010110000000111;
  wire [7:0] n166_o;
  wire [7:0] n167_o;
  wire [7:0] n168_o;
  wire [7:0] n169_o;
  wire n170_o;
  wire [10:0] n172_o;
  wire [1:0] n174_o;
  wire [1:0] n176_o;
  localparam [31:0] n178_o = 32'b10001000001110000000011100111000;
  wire [7:0] n180_o;
  wire [10:0] n182_o;
  wire [1:0] n184_o;
  wire [1:0] n186_o;
  localparam [31:0] n188_o = 32'b00100010001001000110011101010010;
  wire [7:0] n190_o;
  wire [10:0] n192_o;
  wire [1:0] n194_o;
  wire [1:0] n196_o;
  localparam [31:0] n198_o = 32'b00101100101000000010110000000111;
  wire [7:0] n200_o;
  wire [7:0] n201_o;
  wire [7:0] n202_o;
  wire [7:0] n203_o;
  wire n204_o;
  wire [10:0] n206_o;
  wire [1:0] n208_o;
  wire [1:0] n210_o;
  localparam [31:0] n212_o = 32'b10001000001110000000011100111000;
  wire [7:0] n214_o;
  wire [10:0] n216_o;
  wire [1:0] n218_o;
  wire [1:0] n220_o;
  localparam [31:0] n222_o = 32'b00100010001001000110011101010010;
  wire [7:0] n224_o;
  wire [10:0] n226_o;
  wire [1:0] n228_o;
  wire [1:0] n230_o;
  localparam [31:0] n232_o = 32'b00101100101000000010110000000111;
  wire [7:0] n234_o;
  wire [7:0] n235_o;
  wire [7:0] n236_o;
  wire [7:0] n237_o;
  wire n238_o;
  wire [1:0] n240_o;
  wire [1:0] n242_o;
  localparam [31:0] n244_o = 32'b10001000001110000000011100111000;
  wire [7:0] n246_o;
  wire [1:0] n248_o;
  wire [1:0] n250_o;
  localparam [31:0] n252_o = 32'b00100010001001000110011101010010;
  wire [7:0] n254_o;
  wire [1:0] n256_o;
  wire [1:0] n258_o;
  localparam [31:0] n260_o = 32'b00101100101000000010110000000111;
  wire [7:0] n262_o;
  wire [7:0] n263_o;
  wire [7:0] n264_o;
  wire [7:0] n265_o;
  wire [1:0] n266_o;
  wire n268_o;
  wire n270_o;
  wire n272_o;
  wire n273_o;
  wire [1:0] n274_o;
  reg [7:0] n278_o;
  reg [7:0] n282_o;
  reg [7:0] n286_o;
  wire [7:0] n287_o;
  wire [7:0] n288_o;
  wire [7:0] n289_o;
  wire [7:0] n290_o;
  wire [7:0] n291_o;
  wire [7:0] n292_o;
  wire [16:0] n293_o;
  wire [17:0] n294_o;
  reg [7:0] n304_q;
  reg [7:0] n305_q;
  reg [7:0] n306_q;
  reg [5:0] n307_q;
  reg [17:0] n308_q;
  wire n309_o;
  wire n310_o;
  wire n311_o;
  wire [7:0] n312_o;
  wire [7:0] n313_o;
  wire [7:0] n314_o;
  wire [7:0] n315_o;
  wire [1:0] n316_o;
  reg [7:0] n317_o;
  wire [7:0] n318_o;
  wire [7:0] n319_o;
  wire [7:0] n320_o;
  wire [7:0] n321_o;
  wire [1:0] n322_o;
  reg [7:0] n323_o;
  wire [7:0] n324_o;
  wire [7:0] n325_o;
  wire [7:0] n326_o;
  wire [7:0] n327_o;
  wire [1:0] n328_o;
  reg [7:0] n329_o;
  wire [7:0] n330_o;
  wire [7:0] n331_o;
  wire [7:0] n332_o;
  wire [7:0] n333_o;
  wire [1:0] n334_o;
  reg [7:0] n335_o;
  wire [7:0] n336_o;
  wire [7:0] n337_o;
  wire [7:0] n338_o;
  wire [7:0] n339_o;
  wire [1:0] n340_o;
  reg [7:0] n341_o;
  wire [7:0] n342_o;
  wire [7:0] n343_o;
  wire [7:0] n344_o;
  wire [7:0] n345_o;
  wire [1:0] n346_o;
  reg [7:0] n347_o;
  wire [7:0] n348_o;
  wire [7:0] n349_o;
  wire [7:0] n350_o;
  wire [7:0] n351_o;
  wire [1:0] n352_o;
  reg [7:0] n353_o;
  wire [7:0] n354_o;
  wire [7:0] n355_o;
  wire [7:0] n356_o;
  wire [7:0] n357_o;
  wire [1:0] n358_o;
  reg [7:0] n359_o;
  wire [7:0] n360_o;
  wire [7:0] n361_o;
  wire [7:0] n362_o;
  wire [7:0] n363_o;
  wire [1:0] n364_o;
  reg [7:0] n365_o;
  wire [7:0] n366_o;
  wire [7:0] n367_o;
  wire [7:0] n368_o;
  wire [7:0] n369_o;
  wire [1:0] n370_o;
  reg [7:0] n371_o;
  wire [7:0] n372_o;
  wire [7:0] n373_o;
  wire [7:0] n374_o;
  wire [7:0] n375_o;
  wire [1:0] n376_o;
  reg [7:0] n377_o;
  wire [7:0] n378_o;
  wire [7:0] n379_o;
  wire [7:0] n380_o;
  wire [7:0] n381_o;
  wire [1:0] n382_o;
  reg [7:0] n383_o;
  assign VGA_HS = n56_q;
  assign VGA_VS = n58_q;
  assign VGA_HBL = n311_o;
  assign VGA_VBL = vbl_delayed;
  assign VGA_R = n304_q;
  assign VGA_G = n305_q;
  assign VGA_B = n306_q;
  /* vga_controller.vhd:59:16  */
  assign shift_reg = n307_q; // (signal)
  /* vga_controller.vhd:61:16  */
  assign last_hbl = n27_q; // (signal)
  /* vga_controller.vhd:62:16  */
  assign hcount = n28_q; // (signal)
  /* vga_controller.vhd:63:16  */
  assign vcount = n30_q; // (signal)
  /* vga_controller.vhd:72:16  */
  assign vbl_delayed = n32_q; // (signal)
  /* vga_controller.vhd:73:16  */
  assign de_delayed = n308_q; // (signal)
  /* vga_controller.vhd:80:43  */
  assign n10_o = ~HBL;
  /* vga_controller.vhd:80:35  */
  assign n11_o = last_hbl & n10_o;
  /* vga_controller.vhd:84:50  */
  assign n13_o = vcount + 6'b000001;
  /* vga_controller.vhd:83:25  */
  assign n15_o = VBL ? n13_o : 6'b000000;
  /* vga_controller.vhd:89:42  */
  assign n17_o = hcount + 11'b00000000001;
  /* vga_controller.vhd:80:17  */
  assign n19_o = n11_o ? 11'b00000000000 : n17_o;
  /* vga_controller.vhd:79:9  */
  always @(posedge CLK_14M)
    n27_q <= HBL;
  /* vga_controller.vhd:79:9  */
  always @(posedge CLK_14M)
    n28_q <= n19_o;
  /* vga_controller.vhd:79:9  */
  assign n29_o = n11_o ? n15_o : vcount;
  /* vga_controller.vhd:79:9  */
  always @(posedge CLK_14M)
    n30_q <= n29_o;
  /* vga_controller.vhd:79:9  */
  assign n31_o = n11_o ? VBL : vbl_delayed;
  /* vga_controller.vhd:79:9  */
  always @(posedge CLK_14M)
    n32_q <= n31_o;
  /* vga_controller.vhd:98:27  */
  assign n37_o = hcount == 11'b01010110110;
  /* vga_controller.vhd:100:35  */
  assign n39_o = vcount == 6'b100001;
  /* vga_controller.vhd:102:38  */
  assign n41_o = vcount == 6'b100100;
  /* vga_controller.vhd:102:25  */
  assign n43_o = n41_o ? 1'b0 : n58_q;
  /* vga_controller.vhd:100:25  */
  assign n45_o = n39_o ? 1'b1 : n43_o;
  /* vga_controller.vhd:105:30  */
  assign n47_o = hcount == 11'b01011111010;
  /* vga_controller.vhd:105:17  */
  assign n49_o = n47_o ? 1'b0 : n56_q;
  /* vga_controller.vhd:98:17  */
  assign n51_o = n37_o ? 1'b1 : n49_o;
  /* vga_controller.vhd:97:9  */
  always @(posedge CLK_14M)
    n56_q <= n51_o;
  /* vga_controller.vhd:97:9  */
  assign n57_o = n37_o ? n45_o : n58_q;
  /* vga_controller.vhd:97:9  */
  always @(posedge CLK_14M)
    n58_q <= n57_o;
  /* vga_controller.vhd:115:47  */
  assign n65_o = shift_reg[5:1];
  /* vga_controller.vhd:115:36  */
  assign n66_o = {VIDEO, n65_o};
  /* vga_controller.vhd:123:25  */
  assign n68_o = SCREEN_MODE == 2'b00;
  /* vga_controller.vhd:124:25  */
  assign n70_o = SCREEN_MODE == 2'b01;
  /* vga_controller.vhd:125:25  */
  assign n72_o = SCREEN_MODE == 2'b10;
  /* vga_controller.vhd:126:25  */
  assign n74_o = SCREEN_MODE == 2'b11;
  assign n75_o = {n74_o, n72_o, n70_o, n68_o};
  /* vga_controller.vhd:122:17  */
  always @*
    case (n75_o)
      4'b1000: n81_o <= 8'b00100000;
      4'b0100: n81_o <= 8'b00000000;
      4'b0010: n81_o <= 8'b00000000;
      4'b0001: n81_o <= 8'b00000000;
    endcase
  /* vga_controller.vhd:122:17  */
  always @*
    case (n75_o)
      4'b1000: n88_o <= 8'b00001000;
      4'b0100: n88_o <= 8'b00001111;
      4'b0010: n88_o <= 8'b00000000;
      4'b0001: n88_o <= 8'b00000000;
    endcase
  /* vga_controller.vhd:122:17  */
  always @*
    case (n75_o)
      4'b1000: n95_o <= 8'b00000001;
      4'b0100: n95_o <= 8'b00000001;
      4'b0010: n95_o <= 8'b00000000;
      4'b0001: n95_o <= 8'b00000000;
    endcase
  /* vga_controller.vhd:130:31  */
  assign n97_o = ~COLOR_LINE;
  /* vga_controller.vhd:132:37  */
  assign n98_o = shift_reg[2];
  /* vga_controller.vhd:135:41  */
  assign n100_o = SCREEN_MODE == 2'b00;
  /* vga_controller.vhd:136:41  */
  assign n102_o = SCREEN_MODE == 2'b01;
  /* vga_controller.vhd:137:41  */
  assign n104_o = SCREEN_MODE == 2'b10;
  /* vga_controller.vhd:138:41  */
  assign n106_o = SCREEN_MODE == 2'b11;
  assign n107_o = {n106_o, n104_o, n102_o, n100_o};
  /* vga_controller.vhd:134:33  */
  always @*
    case (n107_o)
      4'b1000: n113_o <= 8'b11111111;
      4'b0100: n113_o <= 8'b00000000;
      4'b0010: n113_o <= 8'b11111111;
      4'b0001: n113_o <= 8'b11111111;
    endcase
  /* vga_controller.vhd:134:33  */
  always @*
    case (n107_o)
      4'b1000: n119_o <= 8'b10000000;
      4'b0100: n119_o <= 8'b11000000;
      4'b0010: n119_o <= 8'b11111111;
      4'b0001: n119_o <= 8'b11111111;
    endcase
  /* vga_controller.vhd:134:33  */
  always @*
    case (n107_o)
      4'b1000: n125_o <= 8'b00000001;
      4'b0100: n125_o <= 8'b00000001;
      4'b0010: n125_o <= 8'b11111111;
      4'b0001: n125_o <= 8'b11111111;
    endcase
  /* vga_controller.vhd:132:25  */
  assign n126_o = n98_o ? n113_o : n81_o;
  /* vga_controller.vhd:132:25  */
  assign n127_o = n98_o ? n119_o : n88_o;
  /* vga_controller.vhd:132:25  */
  assign n128_o = n98_o ? n125_o : n95_o;
  /* vga_controller.vhd:142:32  */
  assign n129_o = shift_reg[0];
  /* vga_controller.vhd:142:47  */
  assign n130_o = shift_reg[4];
  /* vga_controller.vhd:142:36  */
  assign n131_o = n129_o == n130_o;
  /* vga_controller.vhd:142:64  */
  assign n132_o = shift_reg[5];
  /* vga_controller.vhd:142:79  */
  assign n133_o = shift_reg[1];
  /* vga_controller.vhd:142:68  */
  assign n134_o = n132_o == n133_o;
  /* vga_controller.vhd:142:51  */
  assign n135_o = n131_o & n134_o;
  /* vga_controller.vhd:145:37  */
  assign n136_o = shift_reg[3];
  /* vga_controller.vhd:146:68  */
  assign n138_o = hcount + 11'b00000000001;
  /* vga_controller.vhd:146:49  */
  assign n140_o = n138_o[1:0];  // trunc
  /* vga_controller.vhd:146:49  */
  assign n142_o = 2'b11 - n140_o;
  /* vga_controller.vhd:146:40  */
  assign n146_o = n81_o + n317_o;
  /* vga_controller.vhd:147:68  */
  assign n148_o = hcount + 11'b00000000001;
  /* vga_controller.vhd:147:49  */
  assign n150_o = n148_o[1:0];  // trunc
  /* vga_controller.vhd:147:49  */
  assign n152_o = 2'b11 - n150_o;
  /* vga_controller.vhd:147:40  */
  assign n156_o = n88_o + n323_o;
  /* vga_controller.vhd:148:68  */
  assign n158_o = hcount + 11'b00000000001;
  /* vga_controller.vhd:148:49  */
  assign n160_o = n158_o[1:0];  // trunc
  /* vga_controller.vhd:148:49  */
  assign n162_o = 2'b11 - n160_o;
  /* vga_controller.vhd:148:40  */
  assign n166_o = n95_o + n329_o;
  /* vga_controller.vhd:145:25  */
  assign n167_o = n136_o ? n146_o : n81_o;
  /* vga_controller.vhd:145:25  */
  assign n168_o = n136_o ? n156_o : n88_o;
  /* vga_controller.vhd:145:25  */
  assign n169_o = n136_o ? n166_o : n95_o;
  /* vga_controller.vhd:150:37  */
  assign n170_o = shift_reg[4];
  /* vga_controller.vhd:151:68  */
  assign n172_o = hcount + 11'b00000000010;
  /* vga_controller.vhd:151:49  */
  assign n174_o = n172_o[1:0];  // trunc
  /* vga_controller.vhd:151:49  */
  assign n176_o = 2'b11 - n174_o;
  /* vga_controller.vhd:151:40  */
  assign n180_o = n167_o + n335_o;
  /* vga_controller.vhd:152:68  */
  assign n182_o = hcount + 11'b00000000010;
  /* vga_controller.vhd:152:49  */
  assign n184_o = n182_o[1:0];  // trunc
  /* vga_controller.vhd:152:49  */
  assign n186_o = 2'b11 - n184_o;
  /* vga_controller.vhd:152:40  */
  assign n190_o = n168_o + n341_o;
  /* vga_controller.vhd:153:68  */
  assign n192_o = hcount + 11'b00000000010;
  /* vga_controller.vhd:153:49  */
  assign n194_o = n192_o[1:0];  // trunc
  /* vga_controller.vhd:153:49  */
  assign n196_o = 2'b11 - n194_o;
  /* vga_controller.vhd:153:40  */
  assign n200_o = n169_o + n347_o;
  /* vga_controller.vhd:150:25  */
  assign n201_o = n170_o ? n180_o : n167_o;
  /* vga_controller.vhd:150:25  */
  assign n202_o = n170_o ? n190_o : n168_o;
  /* vga_controller.vhd:150:25  */
  assign n203_o = n170_o ? n200_o : n169_o;
  /* vga_controller.vhd:155:37  */
  assign n204_o = shift_reg[1];
  /* vga_controller.vhd:156:68  */
  assign n206_o = hcount + 11'b00000000011;
  /* vga_controller.vhd:156:49  */
  assign n208_o = n206_o[1:0];  // trunc
  /* vga_controller.vhd:156:49  */
  assign n210_o = 2'b11 - n208_o;
  /* vga_controller.vhd:156:40  */
  assign n214_o = n201_o + n353_o;
  /* vga_controller.vhd:157:68  */
  assign n216_o = hcount + 11'b00000000011;
  /* vga_controller.vhd:157:49  */
  assign n218_o = n216_o[1:0];  // trunc
  /* vga_controller.vhd:157:49  */
  assign n220_o = 2'b11 - n218_o;
  /* vga_controller.vhd:157:40  */
  assign n224_o = n202_o + n359_o;
  /* vga_controller.vhd:158:68  */
  assign n226_o = hcount + 11'b00000000011;
  /* vga_controller.vhd:158:49  */
  assign n228_o = n226_o[1:0];  // trunc
  /* vga_controller.vhd:158:49  */
  assign n230_o = 2'b11 - n228_o;
  /* vga_controller.vhd:158:40  */
  assign n234_o = n203_o + n365_o;
  /* vga_controller.vhd:155:25  */
  assign n235_o = n204_o ? n214_o : n201_o;
  /* vga_controller.vhd:155:25  */
  assign n236_o = n204_o ? n224_o : n202_o;
  /* vga_controller.vhd:155:25  */
  assign n237_o = n204_o ? n234_o : n203_o;
  /* vga_controller.vhd:160:37  */
  assign n238_o = shift_reg[2];
  /* vga_controller.vhd:161:49  */
  assign n240_o = hcount[1:0];  // trunc
  /* vga_controller.vhd:161:49  */
  assign n242_o = 2'b11 - n240_o;
  /* vga_controller.vhd:161:40  */
  assign n246_o = n235_o + n371_o;
  /* vga_controller.vhd:162:49  */
  assign n248_o = hcount[1:0];  // trunc
  /* vga_controller.vhd:162:49  */
  assign n250_o = 2'b11 - n248_o;
  /* vga_controller.vhd:162:40  */
  assign n254_o = n236_o + n377_o;
  /* vga_controller.vhd:163:49  */
  assign n256_o = hcount[1:0];  // trunc
  /* vga_controller.vhd:163:49  */
  assign n258_o = 2'b11 - n256_o;
  /* vga_controller.vhd:163:40  */
  assign n262_o = n237_o + n383_o;
  /* vga_controller.vhd:160:25  */
  assign n263_o = n238_o ? n246_o : n235_o;
  /* vga_controller.vhd:160:25  */
  assign n264_o = n238_o ? n254_o : n236_o;
  /* vga_controller.vhd:160:25  */
  assign n265_o = n238_o ? n262_o : n237_o;
  /* vga_controller.vhd:168:39  */
  assign n266_o = shift_reg[3:2];
  /* vga_controller.vhd:169:33  */
  assign n268_o = n266_o == 2'b11;
  /* vga_controller.vhd:170:33  */
  assign n270_o = n266_o == 2'b01;
  /* vga_controller.vhd:170:43  */
  assign n272_o = n266_o == 2'b10;
  /* vga_controller.vhd:170:43  */
  assign n273_o = n270_o | n272_o;
  assign n274_o = {n273_o, n268_o};
  /* vga_controller.vhd:168:25  */
  always @*
    case (n274_o)
      2'b10: n278_o <= 8'b10000000;
      2'b01: n278_o <= 8'b11111111;
    endcase
  /* vga_controller.vhd:168:25  */
  always @*
    case (n274_o)
      2'b10: n282_o <= 8'b10000000;
      2'b01: n282_o <= 8'b11111111;
    endcase
  /* vga_controller.vhd:168:25  */
  always @*
    case (n274_o)
      2'b10: n286_o <= 8'b10000000;
      2'b01: n286_o <= 8'b11111111;
    endcase
  /* vga_controller.vhd:142:17  */
  assign n287_o = n135_o ? n263_o : n278_o;
  /* vga_controller.vhd:142:17  */
  assign n288_o = n135_o ? n264_o : n282_o;
  /* vga_controller.vhd:142:17  */
  assign n289_o = n135_o ? n265_o : n286_o;
  /* vga_controller.vhd:130:17  */
  assign n290_o = n97_o ? n126_o : n287_o;
  /* vga_controller.vhd:130:17  */
  assign n291_o = n97_o ? n127_o : n288_o;
  /* vga_controller.vhd:130:17  */
  assign n292_o = n97_o ? n128_o : n289_o;
  /* vga_controller.vhd:179:41  */
  assign n293_o = de_delayed[16:0];
  /* vga_controller.vhd:179:55  */
  assign n294_o = {n293_o, last_hbl};
  /* vga_controller.vhd:114:9  */
  always @(posedge CLK_14M)
    n304_q <= n290_o;
  /* vga_controller.vhd:114:9  */
  always @(posedge CLK_14M)
    n305_q <= n291_o;
  /* vga_controller.vhd:114:9  */
  always @(posedge CLK_14M)
    n306_q <= n292_o;
  /* vga_controller.vhd:114:9  */
  always @(posedge CLK_14M)
    n307_q <= n66_o;
  /* vga_controller.vhd:114:9  */
  always @(posedge CLK_14M)
    n308_q <= n294_o;
  /* vga_controller.vhd:184:22  */
  assign n309_o = de_delayed[9];
  /* vga_controller.vhd:184:40  */
  assign n310_o = de_delayed[17];
  /* vga_controller.vhd:184:26  */
  assign n311_o = n309_o & n310_o;
  /* vga_controller.vhd:45:17  */
  assign n312_o = n144_o[7:0];
  /* vga_controller.vhd:44:17  */
  assign n313_o = n144_o[15:8];
  /* vga_controller.vhd:43:17  */
  assign n314_o = n144_o[23:16];
  /* vga_controller.vhd:42:17  */
  assign n315_o = n144_o[31:24];
  /* vga_controller.vhd:146:49  */
  assign n316_o = n142_o[1:0];
  /* vga_controller.vhd:146:49  */
  always @*
    case (n316_o)
      2'b00: n317_o <= n312_o;
      2'b01: n317_o <= n313_o;
      2'b10: n317_o <= n314_o;
      2'b11: n317_o <= n315_o;
    endcase
  /* vga_controller.vhd:146:50  */
  assign n318_o = n154_o[7:0];
  /* vga_controller.vhd:146:49  */
  assign n319_o = n154_o[15:8];
  /* vga_controller.vhd:39:17  */
  assign n320_o = n154_o[23:16];
  assign n321_o = n154_o[31:24];
  /* vga_controller.vhd:147:49  */
  assign n322_o = n152_o[1:0];
  /* vga_controller.vhd:147:49  */
  always @*
    case (n322_o)
      2'b00: n323_o <= n318_o;
      2'b01: n323_o <= n319_o;
      2'b10: n323_o <= n320_o;
      2'b11: n323_o <= n321_o;
    endcase
  /* vga_controller.vhd:147:50  */
  assign n324_o = n164_o[7:0];
  /* vga_controller.vhd:147:49  */
  assign n325_o = n164_o[15:8];
  /* vga_controller.vhd:114:9  */
  assign n326_o = n164_o[23:16];
  /* vga_controller.vhd:163:50  */
  assign n327_o = n164_o[31:24];
  /* vga_controller.vhd:148:49  */
  assign n328_o = n162_o[1:0];
  /* vga_controller.vhd:148:49  */
  always @*
    case (n328_o)
      2'b00: n329_o <= n324_o;
      2'b01: n329_o <= n325_o;
      2'b10: n329_o <= n326_o;
      2'b11: n329_o <= n327_o;
    endcase
  /* vga_controller.vhd:148:50  */
  assign n330_o = n178_o[7:0];
  /* vga_controller.vhd:148:49  */
  assign n331_o = n178_o[15:8];
  /* vga_controller.vhd:158:50  */
  assign n332_o = n178_o[23:16];
  /* vga_controller.vhd:157:50  */
  assign n333_o = n178_o[31:24];
  /* vga_controller.vhd:151:49  */
  assign n334_o = n176_o[1:0];
  /* vga_controller.vhd:151:49  */
  always @*
    case (n334_o)
      2'b00: n335_o <= n330_o;
      2'b01: n335_o <= n331_o;
      2'b10: n335_o <= n332_o;
      2'b11: n335_o <= n333_o;
    endcase
  /* vga_controller.vhd:151:50  */
  assign n336_o = n188_o[7:0];
  /* vga_controller.vhd:151:49  */
  assign n337_o = n188_o[15:8];
  /* vga_controller.vhd:152:50  */
  assign n338_o = n188_o[23:16];
  /* vga_controller.vhd:151:50  */
  assign n339_o = n188_o[31:24];
  /* vga_controller.vhd:152:49  */
  assign n340_o = n186_o[1:0];
  /* vga_controller.vhd:152:49  */
  always @*
    case (n340_o)
      2'b00: n341_o <= n336_o;
      2'b01: n341_o <= n337_o;
      2'b10: n341_o <= n338_o;
      2'b11: n341_o <= n339_o;
    endcase
  /* vga_controller.vhd:152:50  */
  assign n342_o = n198_o[7:0];
  /* vga_controller.vhd:152:49  */
  assign n343_o = n198_o[15:8];
  /* vga_controller.vhd:146:50  */
  assign n344_o = n198_o[23:16];
  assign n345_o = n198_o[31:24];
  /* vga_controller.vhd:153:49  */
  assign n346_o = n196_o[1:0];
  /* vga_controller.vhd:153:49  */
  always @*
    case (n346_o)
      2'b00: n347_o <= n342_o;
      2'b01: n347_o <= n343_o;
      2'b10: n347_o <= n344_o;
      2'b11: n347_o <= n345_o;
    endcase
  /* vga_controller.vhd:153:50  */
  assign n348_o = n212_o[7:0];
  /* vga_controller.vhd:153:49  */
  assign n349_o = n212_o[15:8];
  /* vga_controller.vhd:111:1  */
  assign n350_o = n212_o[23:16];
  /* vga_controller.vhd:112:24  */
  assign n351_o = n212_o[31:24];
  /* vga_controller.vhd:156:49  */
  assign n352_o = n210_o[1:0];
  /* vga_controller.vhd:156:49  */
  always @*
    case (n352_o)
      2'b00: n353_o <= n348_o;
      2'b01: n353_o <= n349_o;
      2'b10: n353_o <= n350_o;
      2'b11: n353_o <= n351_o;
    endcase
  /* vga_controller.vhd:156:50  */
  assign n354_o = n222_o[7:0];
  /* vga_controller.vhd:156:49  */
  assign n355_o = n222_o[15:8];
  assign n356_o = n222_o[23:16];
  /* vga_controller.vhd:112:18  */
  assign n357_o = n222_o[31:24];
  /* vga_controller.vhd:157:49  */
  assign n358_o = n220_o[1:0];
  /* vga_controller.vhd:157:49  */
  always @*
    case (n358_o)
      2'b00: n359_o <= n354_o;
      2'b01: n359_o <= n355_o;
      2'b10: n359_o <= n356_o;
      2'b11: n359_o <= n357_o;
    endcase
  /* vga_controller.vhd:157:50  */
  assign n360_o = n232_o[7:0];
  /* vga_controller.vhd:157:49  */
  assign n361_o = n232_o[15:8];
  /* vga_controller.vhd:97:9  */
  assign n362_o = n232_o[23:16];
  /* vga_controller.vhd:95:1  */
  assign n363_o = n232_o[31:24];
  /* vga_controller.vhd:158:49  */
  assign n364_o = n230_o[1:0];
  /* vga_controller.vhd:158:49  */
  always @*
    case (n364_o)
      2'b00: n365_o <= n360_o;
      2'b01: n365_o <= n361_o;
      2'b10: n365_o <= n362_o;
      2'b11: n365_o <= n363_o;
    endcase
  /* vga_controller.vhd:158:50  */
  assign n366_o = n244_o[7:0];
  /* vga_controller.vhd:158:49  */
  assign n367_o = n244_o[15:8];
  /* vga_controller.vhd:79:9  */
  assign n368_o = n244_o[23:16];
  /* vga_controller.vhd:77:1  */
  assign n369_o = n244_o[31:24];
  /* vga_controller.vhd:161:49  */
  assign n370_o = n242_o[1:0];
  /* vga_controller.vhd:161:49  */
  always @*
    case (n370_o)
      2'b00: n371_o <= n366_o;
      2'b01: n371_o <= n367_o;
      2'b10: n371_o <= n368_o;
      2'b11: n371_o <= n369_o;
    endcase
  /* vga_controller.vhd:161:50  */
  assign n372_o = n252_o[7:0];
  /* vga_controller.vhd:161:49  */
  assign n373_o = n252_o[15:8];
  assign n374_o = n252_o[23:16];
  assign n375_o = n252_o[31:24];
  /* vga_controller.vhd:162:49  */
  assign n376_o = n250_o[1:0];
  /* vga_controller.vhd:162:49  */
  always @*
    case (n376_o)
      2'b00: n377_o <= n372_o;
      2'b01: n377_o <= n373_o;
      2'b10: n377_o <= n374_o;
      2'b11: n377_o <= n375_o;
    endcase
  /* vga_controller.vhd:162:50  */
  assign n378_o = n260_o[7:0];
  /* vga_controller.vhd:162:49  */
  assign n379_o = n260_o[15:8];
  assign n380_o = n260_o[23:16];
  assign n381_o = n260_o[31:24];
  /* vga_controller.vhd:163:49  */
  assign n382_o = n258_o[1:0];
  /* vga_controller.vhd:163:49  */
  always @*
    case (n382_o)
      2'b00: n383_o <= n378_o;
      2'b01: n383_o <= n379_o;
      2'b10: n383_o <= n380_o;
      2'b11: n383_o <= n381_o;
    endcase
endmodule

