// 顶层模块：打通原理图中的各子模块与逻辑门电路
module timer_top (
    input  wire       clk_1khz,       // 1kHz 时钟信号 (PIN_18)
    input  wire       reset,          // 外部复位按键 (PIN_20)
    input  wire [3:0] row,            // 矩阵键盘行输入 (PIN_23, 24, 27, 28)
    
    output wire [3:0] col,            // 矩阵键盘列扫描输出 (PIN_29, 30, 31, 32)
    output wire [6:0] timer_h_out,    // 主倒计时十位数码管段码 (PIN_102...104)
    output wire [6:0] timer_l_out,    // 主倒计时个位数码管段码 (PIN_88...94)
    output wire [7:0] led_out,        // 8路流水灯/状态指示灯 (PIN_1...8)
    
    // 设置参数显示数码管 (对应原图 4 片 7448 译码器输出)
    output wire [6:0] start_h_seg,    // 起始时间十位 (PIN_140...142)
    output wire [6:0] start_l_seg,    // 起始时间个位 (PIN_130...132)
    output wire [6:0] end_h_seg,      // 截止时间十位 (PIN_120...122)
    output wire [6:0] end_l_seg       // 截止时间个位 (PIN_110...112)
);

    // 内部连线信号声明
    wire [3:0] start_h, start_l;
    wire [3:0] end_h, end_l;
    wire [3:0] timer_h_in, timer_l_in;
    
    wire       auto_load;
    wire       timer_reset;
    wire       reset_total;
    wire [7:0] led_sig;

    // 1. 原理图中的 NOR3 门逻辑: reset_total = ~(auto_load | reset | timer_reset)
    assign reset_total = ~(auto_load | reset | timer_reset);

    // 2. 原理图中的 NOT 门逻辑: 取反驱动 LED (低电平点亮)
    assign led_out = ~led_sig;

    // 3. 矩阵键盘与时间设置模块
    key_set_timer u_key_set_timer (
        .CLK_1kHz (clk_1khz),
        .row      (row),
        .col      (col),
        .start_h  (start_h),
        .start_l  (start_l),
        .end_h    (end_h),
        .end_l    (end_l)
    );

    // 4. 倒计时主控模块
    timer_main u_timer_main (
        .CLK_1kHz    (clk_1khz),
        .reset_total (reset_total),
        .timer_h_in  (timer_h_in),
        .timer_l_in  (timer_l_in),
        .timer_reset (timer_reset)
    );

    // 5. 错误检测与倒计时显示控制模块
    err_select_display u_err_select_display (
        .start_h     (start_h),
        .start_l     (start_l),
        .end_h       (end_h),
        .end_l       (end_l),
        .timer_h_in  (timer_h_in),
        .timer_l_in  (timer_l_in),
        .auto_load   (auto_load),
        .timer_h_out (timer_h_out),
        .timer_l_out (timer_l_out)
    );

    // 6. 流水灯控制模块
    time_compare_enlight u_time_compare_enlight (
        .CLK_1kHz   (clk_1khz),
        .start_h    (start_h),
        .start_l    (start_l),
        .end_h      (end_h),
        .end_l      (end_l),
        .timer_h_in (timer_h_in),
        .timer_l_in (timer_l_in),
        .led_sig    (led_sig)
    );

    // 7. 4 片 7448 译码器替换 (用于 start/end 时间的静态译码显示)
    bcd_to_7seg u_dec_start_h (.bcd(start_h), .seg(start_h_seg));
    bcd_to_7seg u_dec_start_l (.bcd(start_l), .seg(start_l_seg));
    bcd_to_7seg u_dec_end_h   (.bcd(end_h),   .seg(end_h_seg));
    bcd_to_7seg u_dec_end_l   (.bcd(end_l),   .seg(end_l_seg));

endmodule