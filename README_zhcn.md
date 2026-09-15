# Timer-Verilog — Verilog 数字计时系统

> **English version (primary README): [README.md](README.md)** — 本文件为中文辅助说明。

一个用纯 Verilog 实现的数字计时系统：**60→00 秒 BCD 倒计时**，通过矩阵键盘设定一个
`[end, start]` 窗口，倒计时穿过窗口时点亮 **8 步流水灯**；当窗口不可达（`start < end`）时，
数码管显示 **`Er`** 并停止计数。

本项目脱胎于一张 74 系列中小规模集成电路（SSI/MSI）原理图，每个模块对应原图中的若干芯片
（74192 计数器、7485 比较器、74157 选择器、74138 译码器、7448 七段译码器等），
可直接用 Icarus Verilog 仿真，也可综合到 Altera MAX II 等 FPGA/CPLD。

---

## 目录结构

| 文件 | 说明 |
| --- | --- |
| `timer_top.v` | 顶层模块：装配各子模块，并实现原图中的胶合逻辑（NOR3 / NOT 门） |
| `timer_main.v` | 1 kHz→1 Hz 分频 + 60→00 BCD 倒计时（模拟两片级联 74192） |
| `key_set_timer.v` | 矩阵键盘消抖、边沿检测，设定 `start` / `end` 时间 |
| `err_select_display.v` | `start < end` 错误判定 + 数码管段码二选一（`Er` 显示，模拟两片 7485 + 74157） |
| `time_compare_enlight.v` | 窗口比较 + 8 步流水灯（模拟 74138 译码） |
| `bcd_to_7seg.v` | BCD→七段译码（7448 逻辑，高电平点亮），例化 4 次用于 `start`/`end` 静态显示 |
| `tb_timer_top_normal.v` | 功能测试台：合法窗口 `[37, 55]`，6 个观察阶段 |
| `tb_timer_top_error.v` | 宽窗口 `[45, 55]` + 非法窗口 `[10, 30]` 的 `Er` 场景，7 个观察阶段 |
| `tb_timer_top_normal.vcd` / `tb_timer_top.vcd` / `timer_top.vcd` | 仿真波形数据库，可用 GTKWave 打开 |
| `wave_normal1.png` / `wave_normal2.png` / `wave_error.png` | 仿真波形截图 |
| `.gitignore` | 忽略仿真中间产物（`*.vvp`、`*.bak`、Quartus 的 `db/` 等） |

---

## 顶层端口（`timer_top`）

原原理图的引脚分配（MAX II，Quartus 9.1 SP2）：

| 端口 | 方向 | 位宽 | 说明 | 原图引脚 |
| --- | --- | --- | --- | --- |
| `clk_1khz` | in | 1 | 1 kHz 时钟 | `PIN_18` |
| `reset` | in | 1 | 外部复位按键 | `PIN_20` |
| `row` | in | 4 | 矩阵键盘行输入 | `PIN_23, 24, 27, 28` |
| `col` | out | 4 | 矩阵键盘列扫描输出 | `PIN_29, 30, 31, 32` |
| `timer_h_out` | out | 7 | 倒计时十位数码管段码 | `PIN_102...104` |
| `timer_l_out` | out | 7 | 倒计时个位数码管段码 | `PIN_88...94` |
| `led_out` | out | 8 | 8 路流水灯（低电平点亮） | `PIN_1...8` |
| `start_h_seg` | out | 7 | 起始时间十位显示 | `PIN_140...142` |
| `start_l_seg` | out | 7 | 起始时间个位显示 | `PIN_130...132` |
| `end_h_seg` | out | 7 | 截止时间十位显示 | `PIN_120...122` |
| `end_l_seg` | out | 7 | 截止时间个位显示 | `PIN_110...112` |

> 段码位序为 `{g, f, e, d, c, b, a}`，高电平点亮（7448 约定）。

---

## 工作原理

### 1. 时钟与倒计时（`timer_main.v`）

* 1 kHz 输入经 10 位计数器分频：计到 499 翻转，得到 1 Hz 方波；再经两级触发器打拍提取
  **1 Hz 上升沿脉冲** `pulse_1hz`（避免直接用分频输出当时钟）。
* 每个 `pulse_1hz` 做一次 BCD 减 1：个位为 0 时向十位借位（个位变 9、十位减 1），
  减到 `00` 时自动回卷到 `60`（对应两片 74192 的级联预置）。
* `reset_total` **低电平有效**，会把计数器同步预置为 `60`。
* `timer_reset = (timer_h_in == 0) && (timer_l_in == 0)`，即到 `00` 时输出高电平脉冲。

### 2. 键盘设定（`key_set_timer.v`）

* 列线固定为 `4'b1110`（只有第 0 列被拉低），因此每次只有 4 个按键可被读出。
* `row` 经两级触发器同步消抖，再取上升沿得到按键按下脉冲 `key_pressed`。
* 四个按键分别循环累加一个设定值（循环回绕）：

  | 按键 | 作用 | 取值范围 |
  | --- | --- | --- |
  | `row[0]` | `start_h`（起始十位） | 0–5 |
  | `row[1]` | `start_l`（起始个位） | 0–9 |
  | `row[2]` | `end_h`（截止十位） | 0–5 |
  | `row[3]` | `end_l`（截止个位） | 0–9 |

### 3. 窗口比较与流水灯（`time_compare_enlight.v`）

* 时钟再分频出 10 Hz 脉冲，作为流水灯的步进节拍。
* 窗口判定：

  ```verilog
  in_range = (start_time >= end_time) &&
             (current_time <= start_time) &&
             (current_time >= end_time);
  ```

  例如 `start = 50`、`end = 10`，则 50、49、… 、11、10 都算在窗口内。
* 在窗口内时，`led_cnt` 每 10 Hz 步进一次，输出 8 位**一位有效（one-hot）、低电平点亮**的
  流水图形；离开窗口立即清零并熄灭全部 LED（`led_sig = 8'b1111_1111`）。
* 顶层再取反：`assign led_out = ~led_sig;`

### 4. 错误窗口与 `Er` 显示（`err_select_display.v`）

* 核心比较（两片 7485 级联）：

  ```verilog
  assign is_error = ({start_h, start_l} < {end_h, end_l});
  ```

  即**起始时间小于截止时间时窗口不可达**，判为错误。
* `is_error` 直接驱动 `auto_load`，经顶层 NOR3 门
  `assign reset_total = ~(auto_load | reset | timer_reset);`
  使倒计时被钉在 `60` 不再递减。
* 段码选择（74157 二选一）：正常情况下输出倒计时数值的段码；
  `is_error` 为 1 时硬编码输出 `E`（`7'b111_1001`）和 `r`（`7'b101_0000`），即 `Er`。

---

## 仿真（Icarus Verilog）

已在 **Icarus Verilog 12.0** 上验证通过（两个测试台均正常 elaborate、运行至 `$finish`）。
每个测试台需要单独编译：

```bash
# 功能测试台：合法窗口 [37, 55]
iverilog -g2005 -o tb_normal.vvp \
    timer_top.v timer_main.v err_select_display.v \
    time_compare_enlight.v key_set_timer.v bcd_to_7seg.v \
    tb_timer_top_normal.v
vvp tb_normal.vvp
gtkwave tb_timer_top_normal.vcd

# 错误 / 宽窗口测试台：[45, 55] 与非法窗口 [10, 30]
iverilog -g2005 -o tb_error.vvp \
    timer_top.v timer_main.v err_select_display.v \
    time_compare_enlight.v key_set_timer.v bcd_to_7seg.v \
    tb_timer_top_error.v
vvp tb_error.vvp
gtkwave tb_timer_top.vcd
```

测试台参数 `CLK_PERIOD = 10`（10 ns），因此**逻辑上的 1 秒 ≈ 10 µs 仿真时间**；
一次完整运行（含两轮 60→00 循环）约 0.64 s 仿真时间。

两个测试台共 **13 个观察阶段**（`tb_timer_top_normal` 的 Phase 1–6、
`tb_timer_top_error` 的 Phase 1–7）。每个阶段都会打印当时的
`start` / `end` / `timer` / `err` / `range` / `led` 快照，例如：

```
--- Phase 3: Configure start=55, end=37 ---
[24497000]  start=55 end=37 set | start= 5 5 end= 3 7 timer= 5 8 | err=0 range=0 led=11111111

--- Phase 6: Configure start=10, end=30 (illegal) ---
[636137000] t=10 end=30 set  => is_error should be 1 | start= 1 0 end= 3 0 timer= 6 0 | err=1 range=0 led=11111111
```

两处小提示：

* `tb_timer_top_error.v` 内部模块名是 `tb_timer_top`，且 `$dumpfile` 写的是
  `tb_timer_top.vcd`（沿用旧文件名），这是刻意保留的，不是笔误。
* 两个测试台都**不含自检断言**，验证靠逐阶段打印的状态快照与 `.vcd` 波形比对。

---

## 波形截图

| 文件 | 对应场景 |
| --- | --- |
| `wave_normal1.png` | 正常倒计时与合法窗口穿窗过程 |
| `wave_normal2.png` | 倒计时回卷 / 第二循环 |
| `wave_error.png` | 非法窗口 `start=10 < end=30`，`Er` 显示与 LED 熄灭 |
