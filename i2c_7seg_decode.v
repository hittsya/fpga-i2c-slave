module i2c_7seg_decode(
    input [3:0]      number,
    output reg [7:0] segments
);

always @(number) begin 
    case (number)
        4'h0 : seg = 8'hc0; // "0"
        4'h1 : seg = 8'hf9; // "1"
        4'h2 : seg = 8'ha4; // "2"
        4'h3 : seg = 8'hb0; // "3"
        4'h4 : seg = 8'h99; // "4"
        4'h5 : seg = 8'h92; // "5"
        4'h6 : seg = 8'h82; // "6"
        4'h7 : seg = 8'hf8; // "7"
        4'h8 : seg = 8'h80; // "8"
        4'h9 : seg = 8'h90; // "9"
        4'ha : seg = 8'h88; // "A"
        4'hb : seg = 8'h83; // "B"
        4'hc : seg = 8'hc6; // "C"
        4'hd : seg = 8'ha1; // "D"
        4'he : seg = 8'h86; // "E"
        4'hf : seg = 8'h8e; // "F"
        default : seg = 8'hff;
    endcase
end // always@`

endmodule
