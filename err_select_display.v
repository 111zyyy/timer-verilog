module err_select_display (
    input  wire [3:0] start_h,      // 起始时间十位 (BCD)
    input  wire [3:0] start_l,      // 起始时间个位 (BCD)
    input  wire [3:0] end_h,        // 截止时间十位 (BCD)
    input  wire [3:0] end_l,        // 截止时间个位 (BCD)
    input  wire [3:0] timer_h_in,   // 当前倒计时十位 (BCD)
    input  wire [3:0] timer_l_in,   // 当前倒计时个位 (BCD)
    
    output wire       auto_load,    // 错误自动重载信号 (高电平表示 Start < End)
    output wire [6:0] timer_h_out,  // 十位数码管最终段码输出
    output wire [6:0] timer_l_out   // 个位数码管最终段码输出
);

    // 1. err_compare 逻辑：比较 Start 与 End 的大小 (两片 7485 级联)
    // 当 Start > End 时，is_error 触发拉高
    wire is_error;
	assign is_error = ({start_h, start_l} < {end_h, end_l});
    assign auto_load = is_error;

    // 2. err_bcd_7seg 逻辑：将当前倒计时 BCD 转为 7 段数码管段码 (7448 逻辑，高电平点亮)
    reg [6:0] normal_h_seg;
    reg [6:0] normal_l_seg;

    function [6:0] bcd2seg(input [3:0] bcd);
        case (bcd)
            4'h0: bcd2seg = 7'b011_1111; // 0
            4'h1: bcd2seg = 7'b000_0110; // 1
            4'h2: bcd2seg = 7'b101_1011; // 2
            4'h3: bcd2seg = 7'b100_1111; // 3
            4'h4: bcd2seg = 7'b110_0110; // 4
            4'h5: bcd2seg = 7'b110_1101; // 5
            4'h6: bcd2seg = 7'b110_1111; // 6
            4'h7: bcd2seg = 7'b000_0111; // 7
            4'h8: bcd2seg = 7'b111_1111; // 8
            4'h9: bcd2seg = 7'b110_1111; // 9
            default: bcd2seg = 7'b000_0000;
        endcase
    endfunction

    always @(*) begin
        normal_h_seg = bcd2seg(timer_h_in);
        normal_l_seg = bcd2seg(timer_l_in);
    end

    // 3. 错误状态硬编码段码 (根据原理图中 74157 接 VCC/GND 的高低电平值设定)
    // 对应显示 "E" (十位) 和 "r" (个位) 的 7 段图形
    localparam [6:0] SEG_ERR_H = 7'b111_1001; // 十位显示 'E'
    localparam [6:0] SEG_ERR_L = 7'b101_0000; // 个位显示 'r'

    // 4. err_mux_h 和 err_mux_l 逻辑：74157 数据二选一选择器
    // is_error 为 1 时输出错误段码；为 0 时输出正常倒计时段码
    assign timer_h_out = is_error ? SEG_ERR_H : normal_h_seg;
    assign timer_l_out = is_error ? SEG_ERR_L : normal_l_seg;

endmodule