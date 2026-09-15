module key_set_timer (
    input  wire       CLK_1kHz,    // 1kHz 时钟信号
    input  wire [3:0] row,         // 键盘行输入信号

    output wire [3:0] col,         // 键盘列输出信号（第一列接 GND，其余拉高）
    output reg  [3:0] start_h = 4'd0,  // 起始十位，初值 0
    output reg  [3:0] start_l = 4'd0,  // 起始个位，初值 0
    output reg  [3:0] end_h   = 4'd0,  // 截止十位，初值 0
    output reg  [3:0] end_l   = 4'd0   // 截止个位，初值 0
);

    // 列线电平固定：col[0]=0, col[3..1]=1
    assign col = 4'b1110;

    // 1. key_debounce：两级触发器消抖同步
    reg [3:0] row_sync_0 = 4'b0000;
    reg [3:0] row_sync_1 = 4'b0000;

    always @(posedge CLK_1kHz) begin
        row_sync_0 <= row;
        row_sync_1 <= row_sync_0;
    end

    // 2. key_edge_detect：提取按键按下边沿脉冲
    reg [3:0] row_sync_2 = 4'b0000;

    always @(posedge CLK_1kHz) begin
        row_sync_2 <= row_sync_1;
    end

    // 按键按压触发脉冲（高电平有效）
    wire [3:0] key_pressed;
    assign key_pressed = row_sync_1 & (~row_sync_2);

    // 3. key_counters：4 位按键设定计数器
    // key_pressed[0] -> start_h (模 6: 0-5)
    // key_pressed[1] -> start_l (模 10: 0-9)
    // key_pressed[2] -> end_h   (模 6: 0-5)
    // key_pressed[3] -> end_l   (模 10: 0-9)

    // start_h 计数器 (0~5)
    always @(posedge CLK_1kHz) begin
        if (key_pressed[0]) begin
            if (start_h >= 4'd5)
                start_h <= 4'd0;
            else
                start_h <= start_h + 1'b1;
        end
    end

    // start_l 计数器 (0~9)
    always @(posedge CLK_1kHz) begin
        if (key_pressed[1]) begin
            if (start_l >= 4'd9)
                start_l <= 4'd0;
            else
                start_l <= start_l + 1'b1;
        end
    end

    // end_h 计数器 (0~5)
    always @(posedge CLK_1kHz) begin
        if (key_pressed[2]) begin
            if (end_h >= 4'd5)
                end_h <= 4'd0;
            else
                end_h <= end_h + 1'b1;
        end
    end

    // end_l 计数器 (0~9)
    always @(posedge CLK_1kHz) begin
        if (key_pressed[3]) begin
            if (end_l >= 4'd9)
                end_l <= 4'd0;
            else
                end_l <= end_l + 1'b1;
        end
    end

endmodule