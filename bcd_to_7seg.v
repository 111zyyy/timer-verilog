module bcd_to_7seg (
    input  wire [3:0] bcd,       // 4位 BCD 码输入
    output reg  [6:0] seg        // 7位段码输出 (a-g, 高电平点亮)
);

    always @(*) begin
        case (bcd)
            4'h0: seg = 7'b011_1111; // 0
            4'h1: seg = 7'b000_0110; // 1
            4'h2: seg = 7'b101_1011; // 2
            4'h3: seg = 7'b100_1111; // 3
            4'h4: seg = 7'b110_0110; // 4
            4'h5: seg = 7'b110_1101; // 5
            4'h6: seg = 7'b110_1111; // 6
            4'h7: seg = 7'b000_0111; // 7
            4'h8: seg = 7'b111_1111; // 8
            4'h9: seg = 7'b110_1111; // 9
            default: seg = 7'b000_0000;
        endcase
    end

endmodule