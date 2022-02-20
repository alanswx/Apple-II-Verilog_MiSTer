//--------------------------------------------------------------------------------------------
//
// Generated by X-HDL VHDL Translator - Version 2.0.0 Feb. 1, 2011
// Sat Feb 19 2022 14:21:22
//
//      Input file      : 
//      Component name  : disk_ii_rom
//      Author          : 
//      Company         : 
//
//      Description     : 
//
//
//--------------------------------------------------------------------------------------------


module disk_ii_rom(
    addr,
    clk,
    dout
);
    input [7:0]      addr;
    input            clk;
    output reg [7:0] dout;
    
    
    parameter [7:0]  ROM[0:255] = {8'ha2, 8'h20, 8'ha0, 8'h00, 8'ha2, 8'h03, 8'h86, 8'h3c, 8'h8a, 8'h0a, 8'h24, 8'h3c, 8'hf0, 8'h10, 8'h05, 8'h3c, 8'h49, 8'hff, 8'h29, 8'h7e, 8'hb0, 8'h08, 8'h4a, 8'hd0, 8'hfb, 8'h98, 8'h9d, 8'h56, 8'h03, 8'hc8, 8'he8, 8'h10, 8'he5, 8'h20, 8'h58, 8'hff, 8'hba, 8'hbd, 8'h00, 8'h01, 8'h0a, 8'h0a, 8'h0a, 8'h0a, 8'h85, 8'h2b, 8'haa, 8'hbd, 8'h8e, 8'hc0, 8'hbd, 8'h8c, 8'hc0, 8'hbd, 8'h8a, 8'hc0, 8'hbd, 8'h89, 8'hc0, 8'ha0, 8'h50, 8'hbd, 8'h80, 8'hc0, 8'h98, 8'h29, 8'h03, 8'h0a, 8'h05, 8'h2b, 8'haa, 8'hbd, 8'h81, 8'hc0, 8'ha9, 8'h56, 8'h20, 8'ha8, 8'hfc, 8'h88, 8'h10, 8'heb, 8'h85, 8'h26, 8'h85, 8'h3d, 8'h85, 8'h41, 8'ha9, 8'h08, 8'h85, 8'h27, 8'h18, 8'h08, 8'hbd, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'h49, 8'hd5, 8'hd0, 8'hf7, 8'hbd, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'hc9, 8'haa, 8'hd0, 8'hf3, 8'hea, 8'hbd, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'hc9, 8'h96, 8'hf0, 8'h09, 8'h28, 8'h90, 8'hdf, 8'h49, 8'had, 8'hf0, 8'h25, 8'hd0, 8'hd9, 8'ha0, 8'h03, 8'h85, 8'h40, 8'hbd, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'h2a, 8'h85, 8'h3c, 8'hbd, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'h25, 8'h3c, 8'h88, 8'hd0, 8'hec, 8'h28, 8'hc5, 8'h3d, 8'hd0, 8'hbe, 8'ha5, 8'h40, 8'hc5, 8'h41, 8'hd0, 8'hb8, 8'hb0, 8'hb7, 8'ha0, 8'h56, 8'h84, 8'h3c, 8'hbc, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'h59, 8'hd6, 8'h02, 8'ha4, 8'h3c, 8'h88, 8'h99, 8'h00, 8'h03, 8'hd0, 8'hee, 8'h84, 8'h3c, 8'hbc, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'h59, 8'hd6, 8'h02, 8'ha4, 8'h3c, 8'h91, 8'h26, 8'hc8, 8'hd0, 8'hef, 8'hbc, 8'h8c, 8'hc0, 8'h10, 8'hfb, 8'h59, 8'hd6, 8'h02, 8'hd0, 8'h87, 8'ha0, 8'h00, 8'ha2, 8'h56, 8'hca, 8'h30, 8'hfb, 8'hb1, 8'h26, 8'h5e, 8'h00, 8'h03, 8'h2a, 8'h5e, 8'h00, 8'h03, 8'h2a, 8'h91, 8'h26, 8'hc8, 8'hd0, 8'hee, 8'he6, 8'h27, 8'he6, 8'h3d, 8'ha5, 8'h3d, 8'hcd, 8'h00, 8'h08, 8'ha6, 8'h2b, 8'h90, 8'hdb, 8'h4c, 8'h01, 8'h08, 8'h00, 8'h00, 8'h00, 8'h00, 8'h00};
    
    
    always @(posedge clk)
        
            dout <= ROM[addr];
    
endmodule
