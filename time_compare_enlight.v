module time_compare_enlight (
    input  wire       CLK_1kHz,      // 1kHz 时钟信号
    input  wire [3:0] start_h,       // 起始时间十位
    input  wire [3:0] start_l,       // 起始时间个位
    input  wire [3:0] end_h,         // 截止时间十位
    input  wire [3:0] end_l,         // 截止时间个位
    input  wire [3:0] timer_h_in,    // 当前倒计时十位
    input  wire [3:0] timer_l_in,    // 当前倒计时个位

    output reg  [7:0] led_sig        // 8路流水灯输出信号（低电平点亮）
);

    // ============================================================
    // 1. 分频逻辑：1kHz -> 10Hz
    // ============================================================
    reg [5:0] clk_cnt = 6'd0;
    reg       clk_10hz = 1'b0;

    always @(posedge CLK_1kHz) begin
        if (clk_cnt >= 6'd49) begin
            clk_cnt  <= 6'd0;
            clk_10hz <= ~clk_10hz;
        end else begin
            clk_cnt <= clk_cnt + 1'b1;
        end
    end

    // ============================================================
    // 2. 提取 10Hz 上升沿脉冲
    // ============================================================
    reg clk_10hz_d1 = 1'b0;
    reg clk_10hz_d2 = 1'b0;
    wire pulse_10hz;

    always @(posedge CLK_1kHz) begin
        clk_10hz_d1 <= clk_10hz;
        clk_10hz_d2 <= clk_10hz_d1;
    end

    assign pulse_10hz = clk_10hz_d1 && (~clk_10hz_d2);

    // ============================================================
    // 3. 时间比较
    //
    // 倒计时是从 Start 向 End 递减：
    //
    //     Start >= Current >= End
    //
    // 例如：
    //     Start = 50
    //     End   = 10
    //
    //     50, 49, 48, ... 11, 10
    //     都属于有效区间
    // ============================================================
    wire [7:0] current_time;
    wire [7:0] start_time;
    wire [7:0] end_time;

    assign current_time = {timer_h_in, timer_l_in};
    assign start_time   = {start_h, start_l};
    assign end_time     = {end_h, end_l};

    wire in_range;

    assign in_range =
        (start_time >= end_time) &&
        (current_time <= start_time) &&
        (current_time >= end_time);

    // ============================================================
    // 4. 8路流水灯计数器
    // ============================================================
    reg [2:0] led_cnt = 3'd0;

    always @(posedge CLK_1kHz) begin
        if (!in_range) begin
            led_cnt <= 3'd0;
        end else if (pulse_10hz) begin
            led_cnt <= led_cnt + 1'b1;
        end
    end

    // ============================================================
    // 5. 74138 译码逻辑
    //
    // 低电平点亮，因此任意时刻只有一路为 0。
    // ============================================================
    always @(*) begin
        if (in_range) begin
            case (led_cnt)
                3'b000: led_sig = 8'b1111_1110;
                3'b001: led_sig = 8'b1111_1101;
                3'b010: led_sig = 8'b1111_1011;
                3'b011: led_sig = 8'b1111_0111;
                3'b100: led_sig = 8'b1110_1111;
                3'b101: led_sig = 8'b1101_1111;
                3'b110: led_sig = 8'b1011_1111;
                3'b111: led_sig = 8'b0111_1111;
                default: led_sig = 8'b1111_1111;
            endcase
        end else begin
            led_sig = 8'b1111_1111;
        end
    end

endmodule