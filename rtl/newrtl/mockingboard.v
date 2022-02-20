//--------------------------------------------------------------------------------------------
//
// Generated by X-HDL VHDL Translator - Version 2.0.0 Feb. 1, 2011
// Sat Feb 19 2022 14:30:43
//
//      Input file      : 
//      Component name  : mockingboard
//      Author          : 
//      Company         : 
//
//      Description     : 
//
//
//--------------------------------------------------------------------------------------------

//
// Mockingboard clone for the Apple II
// Model A: two AY-3-8913 chips for six audio channels
//
// Top file by W. Soltys <wsoltys@gmail.com>
// 
// loosely based on:
// http://www.downloads.reactivemicro.com/Public/Apple%20II%20Items/Hardware/Mockingboard_v1/Mockingboard-v1a-Docs.pdf
// http://www.applelogic.org/CarteBlancheIIProj6.html
//

//  use ieee.std_logic_unsigned.all;

module MOCKINGBOARD(
    CLK_14M,
    PHASE_ZERO,
    I_ADDR,
    I_DATA,
    O_DATA,
    I_RW_L,
    O_IRQ_L,
    O_NMI_L,
    I_IOSEL_L,
    I_RESET_L,
    I_ENA_H,
    O_AUDIO_L,
    O_AUDIO_R
);
    input        CLK_14M;
    input        PHASE_ZERO;
    input [7:0]  I_ADDR;
    input [7:0]  I_DATA;
    output [7:0] O_DATA;
    
    input        I_RW_L;
    output       O_IRQ_L;
    output       O_NMI_L;
    input        I_IOSEL_L;
    input        I_RESET_L;
    input        I_ENA_H;
    
    output [9:0] O_AUDIO_L;
    output [9:0] O_AUDIO_R;
    
    
    wire [7:0]   o_pb_l;
    wire [7:0]   o_pb_r;
    
    wire [7:0]   i_psg_r;
    wire [7:0]   o_psg_r;
    wire [7:0]   i_psg_l;
    wire [7:0]   o_psg_l;
    
    wire [7:0]   o_psg_al;
    wire [7:0]   o_psg_bl;
    wire [7:0]   o_psg_cl;
    wire [9:0]   o_psg_ol;
    
    wire [7:0]   o_psg_ar;
    wire [7:0]   o_psg_br;
    wire [7:0]   o_psg_cr;
    wire [9:0]   o_psg_or;
    
    wire [7:0]   o_data_l;
    wire [7:0]   o_data_r;
    
    wire         lirq;
    wire         rirq;
    
    wire         PSG_EN;
    wire         VIA_CE_F;
    wire         VIA_CE_R;
    reg          PHASE_ZERO_D;
    
    // Bus Direction (0 - read , 1 - write)
    // Bus control
    
    assign O_DATA = (I_ADDR[7] == 1'b0) ? o_data_l : 
                    o_data_r;
    assign O_IRQ_L = (~lirq) | (~I_ENA_H);
    assign O_NMI_L = (~rirq) | (~I_ENA_H);
    
    assign PSG_EN = (PHASE_ZERO == 1'b0 & PHASE_ZERO_D == 1'b1) ? 1'b1 : 
                    1'b0;
    assign VIA_CE_R = (PHASE_ZERO == 1'b1 & PHASE_ZERO_D == 1'b0) ? 1'b1 : 
                      1'b0;
    assign VIA_CE_F = (PHASE_ZERO == 1'b0 & PHASE_ZERO_D == 1'b1) ? 1'b1 : 
                      1'b0;
    
    
    always @(posedge CLK_14M)
        
            PHASE_ZERO_D <= PHASE_ZERO;
    
    // Left Channel Combo
    
    work.via6522 m6522_left(
        .clock(CLK_14M),
        .rising(VIA_CE_R),
        .falling(VIA_CE_F),
        .reset((~I_RESET_L)),
        
        .addr(I_ADDR[3:0]),
        .wen((~I_RW_L) & (~I_ADDR[7]) & (~I_IOSEL_L) & I_ENA_H),
        .ren(I_RW_L & (~I_ADDR[7]) & (~I_IOSEL_L) & I_ENA_H),
        .data_in(I_DATA),
        .data_out(o_data_l),
        
        .phi2_ref(),
        
        .port_a_o(i_psg_l),
        .port_a_t(),
        .port_a_i(o_psg_l),
        
        .port_b_o(o_pb_l),
        .port_b_t(),
        .port_b_i(1'b1),
        
        .ca1_i(1'b1),
        .ca2_o(),
        .ca2_i(1'b1),
        .cb1_o(),
        .cb1_i(1'b1),
        .cb1_t(),
        .cb2_o(),
        .cb2_i(1'b1),
        .cb2_t(),
        .irq(lirq)
    );
    
    
    YM2149 psg_left(
        .clk(CLK_14M),
        .ce(PSG_EN & I_ENA_H),
        .reset((~o_pb_l[2])),
        .bdir(o_pb_l[1]),
        .bc(o_pb_l[0]),
        .di(i_psg_l),
        .do(o_psg_l),
        .channel_a(o_psg_al),
        .channel_b(o_psg_bl),
        .channel_c(o_psg_cl),
        
        .sel(1'b0),
        .mode(1'b0),
        
        .active(),
        
        .ioa_in(1'b0),
        .ioa_out(),
        
        .iob_in(1'b0),
        .iob_out()
    );
    
    assign O_AUDIO_L = (({2'b00, o_psg_al}) + ({2'b00, o_psg_bl}) + ({2'b00, o_psg_cl}));
    
    // Right Channel Combo
    
    work.via6522 m6522_right(
        .clock(CLK_14M),
        .rising(VIA_CE_R),
        .falling(VIA_CE_F),
        .reset((~I_RESET_L)),
        
        .addr(I_ADDR[3:0]),
        .wen((~I_RW_L) & I_ADDR[7] & (~I_IOSEL_L) & I_ENA_H),
        .ren(I_RW_L & I_ADDR[7] & (~I_IOSEL_L) & I_ENA_H),
        .data_in(I_DATA),
        .data_out(o_data_r),
        
        .phi2_ref(),
        
        .port_a_o(i_psg_r),
        .port_a_t(),
        .port_a_i(o_psg_r),
        
        .port_b_o(o_pb_r),
        .port_b_t(),
        .port_b_i({10{1'b1}}),
        
        .ca1_i(1'b1),
        .ca2_o(),
        .ca2_i(1'b1),
        .cb1_o(),
        .cb1_i(1'b1),
        .cb1_t(),
        .cb2_o(),
        .cb2_i(1'b1),
        .cb2_t(),
        .irq(rirq)
    );
    
    
    YM2149 psg_right(
        .clk(CLK_14M),
        .ce(PSG_EN & I_ENA_H),
        .reset((~o_pb_r[2])),
        .bdir(o_pb_r[1]),
        .bc(o_pb_r[0]),
        .di(i_psg_r),
        .do(o_psg_r),
        .channel_a(o_psg_ar),
        .channel_b(o_psg_br),
        .channel_c(o_psg_cr),
        
        .sel(1'b0),
        .mode(1'b0),
        
        .active(),
        
        .ioa_in({10{1'b0}}),
        .ioa_out(),
        
        .iob_in({10{1'b0}}),
        .iob_out()
    );
    
    assign O_AUDIO_R = (({2'b00, o_psg_ar}) + ({2'b00, o_psg_br}) + ({2'b00, o_psg_cr}));
    
endmodule
