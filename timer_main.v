module timer_main (
    input  wire       CLK_1kHz,       // 1kHz 输入时钟
    input  wire       reset_total,    // 低电平有效的全局同步预置/复位信号
    output reg  [3:0] timer_h_in,     // 倒计时十位 BCD 码
    output reg  [3:0] timer_l_in,     // 倒计时个位 BCD 码
    output wire       timer_reset     // 归零/重置脉冲信号
);

    // 1. 内部分频计数器：1kHz -> 1Hz (1000个周期产生一个1Hz脉冲)
    reg [9:0] clk_cnt = 10'd0;
    reg       clk_1hz = 1'b0;

    always @(posedge CLK_1kHz) begin
        if (clk_cnt >= 10'd499) begin
            clk_cnt <= 10'd0;
            clk_1hz <= ~clk_1hz;      // 翻转产生 1Hz 方波
        end else begin
            clk_cnt <= clk_cnt + 1'b1;
        end
    end

    // 提取 1Hz 信号的上升沿脉冲，避免时钟域同步问题
    reg clk_1hz_d1, clk_1hz_d2;
    wire pulse_1hz;

    always @(posedge CLK_1kHz) begin
        clk_1hz_d1 <= clk_1hz;
        clk_1hz_d2 <= clk_1hz_d1;
    end
    assign pulse_1hz = clk_1hz_d1 && (~clk_1hz_d2);

    // 2. 60秒 BCD 减法计数逻辑 (模拟两片 74192)
    always @(posedge CLK_1kHz) begin
        if (!reset_total) begin
            // 低电平预置/复位，初始重置为 60 秒
            timer_h_in <= 4'd6;
            timer_l_in <= 4'd0;
        end else if (pulse_1hz) begin
            if (timer_l_in == 4'd0) begin
                if (timer_h_in == 4'd0) begin
                    // 计数到 00 秒时自动回到 60 秒
                    timer_h_in <= 4'd6;
                    timer_l_in <= 4'd0;
                end else begin
                    // 个位借位：个位变为 9，十位减 1
                    timer_l_in <= 4'd9;
                    timer_h_in <= timer_h_in - 1'b1;
                end
            end else begin
                // 个位正常递减
                timer_l_in <= timer_l_in - 1'b1;
            end
        end
    end

    // 3. 原理图中的 AND2 复位信号输出逻辑
    // 当倒计时减至 00 秒时输出高电平脉冲
    assign timer_reset = (timer_h_in == 4'd0) && (timer_l_in == 4'd0);

endmodule