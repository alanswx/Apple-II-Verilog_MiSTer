//--------------------------------------------------------------------------------------------
//
// Generated by X-HDL VHDL Translator - Version 2.0.0 Feb. 1, 2011
// Sat Mar 5 2022 16:56:13
//
//      Input file      : 
//      Component name  : fadd
//      Author          : 
//      Company         : 
//
//      Description     : 
//
//
//--------------------------------------------------------------------------------------------

module fadd(
    a,
    b,
    cin,
    s,
    cout
);
    input   a;
    input   b;
    input   cin;
    output  s;
    output  cout;
    assign #1 s =  a ^ b ^ cin;
    assign #1 cout =  (a & b) | (a & cin) | (b & cin);
    
endmodule
