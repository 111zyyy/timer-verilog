// ============================================================================
// 测试平台: tb_timer_top.v  (改版: 宽窗口 [45,55] + Er 错误场景)
// ============================================================================
`timescale 1ns/1ps

module tb_timer_top;

    parameter CLK_PERIOD = 10;   // 仿真时钟周期 10ns, 逻辑上等效 1kHz

    reg        clk_1khz;
    reg        reset;
    reg  [3:0] row;

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

    // 观测信号 (方便 VCD 抓取)
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
        $dumpfile("tb_timer_top.vcd");
        $dumpvars(0, tb_timer_top);
    end

    // 一次按键 = 一个上升沿脉冲
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

    initial begin
        clk_1khz = 1'b0;
        reset    = 1'b1;
        row      = 4'b0000;

        $display("==========================================================");
        $display("  timer_top TB  --  window=[45,55] + Er scenario");
        $display("==========================================================");

        // ------------------------------------------------------------------
        // Phase 1: 复位, 倒计时应为 60
        // ------------------------------------------------------------------
        $display("\n--- Phase 1: Assert reset ---");
        #(CLK_PERIOD * 50);
        show_state("reset asserted");

        // ------------------------------------------------------------------
        // Phase 2: 释放复位, 观察 60->59->58
        //   1 个倒计时秒 = 1000 个 clk (1000 * 10ns = 10us 仿真时间)
        // ------------------------------------------------------------------
        $display("\n--- Phase 2: Release reset, countdown 60->59->58 ---");
        reset = 1'b0;
        #(CLK_PERIOD * 100);
        show_state("t~0.1s");

        #(CLK_PERIOD * 1100);
        show_state("t~1.2s  (should show 59)");

        #(CLK_PERIOD * 1000);
        show_state("t~2.2s  (should show 58)");

        // ------------------------------------------------------------------
        // Phase 3: 设置合法宽窗口  start=55, end=45
        //   此刻四个键盘计数器初值均为 0, 直接 repeat 到目标值
        // ------------------------------------------------------------------
        $display("\n--- Phase 3: Configure start=55, end=45 (legal wide window) ---");
        repeat(5) press_key(0);   // start_h: 0 -> 5
        repeat(5) press_key(1);   // start_l: 0 -> 5
        repeat(4) press_key(2);   // end_h:   0 -> 4
        repeat(5) press_key(3);   // end_l:   0 -> 5
        #(CLK_PERIOD * 20);
        show_state("start=55 end=45 set");

        // ------------------------------------------------------------------
        // Phase 4: 观察倒计时穿窗
        //   从 60 减到 55 需要 5 秒 = 5000 clk
        //   55 到 45 是窗口内 = 10000 clk (流水灯会走 100 步)
        // ------------------------------------------------------------------
        $display("\n--- Phase 4: Watch countdown crossing window [55..45] ---");

        #(CLK_PERIOD * 5000);
        show_state("countdown ~55 (ENTER window, marquee ON)");

        #(CLK_PERIOD * 3000);
        show_state("countdown ~52 (inside window, marquee walking)");

        #(CLK_PERIOD * 3000);
        show_state("countdown ~49 (inside window, marquee walking)");

        #(CLK_PERIOD * 4000);
        show_state("countdown ~45 (EXIT window edge)");

        #(CLK_PERIOD * 2000);
        show_state("countdown ~43 (out of window, LEDs blank)");

        // ------------------------------------------------------------------
        // Phase 5: 一路减到 00, 观察 timer_reset 脉冲与自动回卷 60
        //   43 秒 = 43000 clk
        // ------------------------------------------------------------------
        $display("\n--- Phase 5: Countdown to 00 -> timer_reset -> reload 60 ---");
        #(CLK_PERIOD * 43000);
        show_state("countdown reached 00 (timer_reset pulses here)");

        #(CLK_PERIOD * 1000);
        show_state("auto-reloaded to 60");

        // ------------------------------------------------------------------
        // Phase 6: 非法场景  start=10, end=30  (start < end -> is_error=1)
        //   当前:  start_h=5, start_l=5, end_h=4, end_l=5
        //   目标:  start_h=1, start_l=0, end_h=3, end_l=0
        //   模 6 / 模 10 计数, 按差值求次数:
        //     start_h: 5 -> 0 -> 1        (2 次)
        //     start_l: 5 -> 6..9 -> 0     (5 次)
        //     end_h:   4 -> 5 -> 0..2 -> 3(5 次)
        //     end_l:   5 -> 6..9 -> 0     (5 次)
        // ------------------------------------------------------------------
        $display("\n--- Phase 6: Configure start=10, end=30 (illegal) ---");
        repeat(2) press_key(0);
        repeat(5) press_key(1);
        repeat(5) press_key(2);
        repeat(5) press_key(3);
        #(CLK_PERIOD * 20);
        show_state("start=10 end=30 set  => is_error should be 1");

        // ------------------------------------------------------------------
        // Phase 7: 观察 Er 显示稳定
        // ------------------------------------------------------------------
        $display("\n--- Phase 7: Observe Er display and blanked LEDs ---");
        #(CLK_PERIOD * 5000);
        show_state("Er state stable");

        $display("\n==========================================================");
        $display("  Simulation complete.");
        $display("  Open tb_timer_top.vcd in GTKWave.");
        $display("==========================================================");
        $finish;
    end

endmodule