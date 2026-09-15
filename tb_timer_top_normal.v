// ============================================================================
// 测试平台: tb_timer_top_normal.v
// 场景: 正常倒计时 + 合法窗口 [37, 55]  (间隔 18 秒)
// VCD : tb_timer_top_normal.vcd
//
// 编译:
//   iverilog -o tb_normal.vvp tb_timer_top_normal.v ^
//       timer_top.v timer_main.v err_select_display.v ^
//       time_compare_enlight.v key_set_timer.v bcd_to_7seg.v
//   vvp tb_normal.vvp
//   gtkwave tb_timer_top_normal.vcd
// ============================================================================
`timescale 1ns/1ps

module tb_timer_top_normal;

    parameter CLK_PERIOD = 10;   // 1 个倒计时秒 = 1000 clk = 10us 仿真时间

    // ---------------- DUT 输入 ----------------
    reg        clk_1khz;
    reg        reset;
    reg  [3:0] row;

    // ---------------- DUT 输出 ----------------
    wire [3:0] col;
    wire [6:0] timer_h_out;
    wire [6:0] timer_l_out;
    wire [7:0] led_out;
    wire [6:0] start_h_seg;
    wire [6:0] start_l_seg;
    wire [6:0] end_h_seg;
    wire [6:0] end_l_seg;

    timer_top dut (
        .clk_1khz    (clk_1khz),
        .reset       (reset),
        .row         (row),
        .col         (col),
        .timer_h_out (timer_h_out),
        .timer_l_out (timer_l_out),
        .led_out     (led_out),
        .start_h_seg (start_h_seg),
        .start_l_seg (start_l_seg),
        .end_h_seg   (end_h_seg),
        .end_l_seg   (end_l_seg)
    );

    initial clk_1khz = 1'b0;
    always #(CLK_PERIOD/2) clk_1khz = ~clk_1khz;

    // ---------------- 内部观测信号 ----------------
    wire [3:0] start_h       = dut.start_h;
    wire [3:0] start_l       = dut.start_l;
    wire [3:0] end_h         = dut.end_h;
    wire [3:0] end_l         = dut.end_l;
    wire [3:0] timer_h       = dut.timer_h_in;
    wire [3:0] timer_l       = dut.timer_l_in;
    wire       auto_load     = dut.auto_load;
    wire       timer_reset_s = dut.timer_reset;
    wire       reset_total   = dut.reset_total;
    wire [7:0] led_sig       = dut.led_sig;
    wire [2:0] led_cnt       = dut.u_time_compare_enlight.led_cnt;
    wire       in_range      = dut.u_time_compare_enlight.in_range;
    wire       is_error      = dut.u_err_select_display.is_error;

    initial begin
        $dumpfile("tb_timer_top_normal.vcd");
        $dumpvars(0, tb_timer_top_normal);
    end

    // ---------------- 任务 ----------------
    task press_key(input integer idx);
        begin
            @(posedge clk_1khz);
            #(CLK_PERIOD/4);
            row[idx] = 1'b1;
            #(CLK_PERIOD * 4);
            row[idx] = 1'b0;
            #(CLK_PERIOD * 4);
        end
    endtask

    task show_state(input [8*40-1:0] tag);
        begin
            $display("[%0t] %s | start=%d%d end=%d%d timer=%d%d | err=%b range=%b led=%b",
                     $time, tag,
                     start_h, start_l, end_h, end_l,
                     timer_h, timer_l,
                     is_error, in_range, led_sig);
        end
    endtask

    // ---------------- 主测试流程 ----------------
    initial begin
        clk_1khz = 1'b0;
        reset    = 1'b1;
        row      = 4'b0000;

        $display("==========================================================");
        $display("  timer_top NORMAL scenario  (window = [37, 55], 18s wide)");
        $display("==========================================================");

        // ----------------------------------------------------------------
        // Phase 1: 复位
        // ----------------------------------------------------------------
        $display("\n--- Phase 1: Assert reset (timer should preset to 60) ---");
        #(CLK_PERIOD * 50);
        show_state("reset asserted");

        // ----------------------------------------------------------------
        // Phase 2: 释放复位, 观察 60->59->58
        // ----------------------------------------------------------------
        $display("\n--- Phase 2: Release reset, countdown 60->59->58 ---");
        reset = 1'b0;
        #(CLK_PERIOD * 100);
        show_state("t~0.1s");

        #(CLK_PERIOD * 1100);
        show_state("t~1.2s  expect 59");

        #(CLK_PERIOD * 1000);
        show_state("t~2.2s  expect 58");

        // ----------------------------------------------------------------
        // Phase 3: 设置窗口 start=55, end=37  (18 秒间隔)
        //   键计数器初值均 0, 直接 repeat 到目标值:
        //     start_h: 0 -> 5   (5 次)
        //     start_l: 0 -> 5   (5 次)
        //     end_h:   0 -> 3   (3 次)
        //     end_l:   0 -> 7   (7 次)
        // ----------------------------------------------------------------
        $display("\n--- Phase 3: Configure start=55, end=37 ---");
        repeat(5) press_key(0);
        repeat(5) press_key(1);
        repeat(3) press_key(2);
        repeat(7) press_key(3);
        #(CLK_PERIOD * 20);
        show_state("start=55 end=37 set");

        // ----------------------------------------------------------------
        // Phase 4: 穿窗过程
        //   此时倒计时约 58, 从 58 -> 55 需 3 秒 = 3000 clk
        // ----------------------------------------------------------------
        $display("\n--- Phase 4: Watch countdown crossing window [55..37] ---");

        #(CLK_PERIOD * 3000);
        show_state("expect ~55  -> ENTER window, marquee starts");

        #(CLK_PERIOD * 3000);
        show_state("expect ~52  -> inside window");

        #(CLK_PERIOD * 6000);
        show_state("expect ~46  -> inside window");

        #(CLK_PERIOD * 6000);
        show_state("expect ~40  -> inside window, near end");

        #(CLK_PERIOD * 3000);
        show_state("expect ~37  -> EXIT window edge");

        #(CLK_PERIOD * 2000);
        show_state("expect ~35  -> out of window, LEDs blank");

        // ----------------------------------------------------------------
        // Phase 5: 一路减到 00, 观察 timer_reset 脉冲与回卷到 60
        //   35 秒 = 35000 clk
        // ----------------------------------------------------------------
        $display("\n--- Phase 5: Countdown to 00 -> timer_reset -> reload 60 ---");
        #(CLK_PERIOD * 35000);
        show_state("expect 00   -> timer_reset pulses");

        #(CLK_PERIOD * 1000);
        show_state("expect 60   -> auto reloaded");

        // ----------------------------------------------------------------
        // Phase 6: 再看一小段, 确认第二循环开始
        // ----------------------------------------------------------------
        $display("\n--- Phase 6: Second cycle begins ---");
        #(CLK_PERIOD * 3000);
        show_state("expect 57   -> second cycle counting down");

        $display("\n==========================================================");
        $display("  Simulation complete.");
        $display("  VCD file: tb_timer_top_normal.vcd");
        $display("==========================================================");
        $finish;
    end

endmodule