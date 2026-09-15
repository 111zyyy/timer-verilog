# Verilog Digital Timer with Programmable Blink Window

A synthesizable Verilog design of a **60 → 00 s BCD countdown timer** with a keyboard-programmable
activity window and an **8-step LED marquee**. The design was originally realised as a discrete
74-series logic circuit, then re-implemented in RTL, verified by simulation, and synthesised for an
Altera MAX II CPLD.

**中文说明 / Chinese documentation:** [README_zhcn.md](README_zhcn.md)

---

## Overview

The timer counts down from 60 to 00 seconds in BCD. Using a 4-key scanned keypad the user programs a
time window `[end, start]`. While the countdown passes through that window, an 8-step one-hot LED
marquee advances at 10 Hz; outside the window the LEDs are blanked and the marquee position resets.
If the programmed window is unreachable — that is, `start < end` — the countdown is inhibited and the
display shows `Er`.

Because the design began as a gate-level schematic built from 74-series SSI/MSI devices, every RTL
module maps directly onto a block of that schematic. The repository therefore also documents a
complete "hardware schematic → synthesizable RTL" translation.

## What this project demonstrates

- **Hierarchical RTL design** in Verilog, from a top-level instantiation down to leaf modules
- **Clock division with edge-detected enable pulses** instead of gated clocks
- **BCD arithmetic** with explicit borrow handling (equivalent to cascaded 74192 counters)
- **Keypad interfacing**: column drive, two-stage synchroniser, debouncing, edge-triggered events
- **Combinational magnitude comparison** of two packed BCD values (equivalent to cascaded 7485)
- **Multiplexed 7-segment display encoding**, including an out-of-range error state
- **Verification workflow**: two directed testbenches, VCD capture, waveform-based analysis
- **Synthesis-aware coding style** targeting a CPLD with fixed pin assignments

## Design origin: mapping to 74-series logic

| RTL module | Replaces (in the original schematic) | Function |
| --- | --- | --- |
| `timer_top.v` | glue logic (NOR3 gate, inverter) | Top level: sub-module instantiation, reset gating, active-low LED drive |
| `timer_main.v` | 2 × 74192 (cascaded) | 1 kHz → 1 Hz division and 60 → 00 BCD countdown with automatic reload |
| `key_set_timer.v` | keypad scan + debounce + presettable counters | Scanned keypad, sets the `start` / `end` BCD digits |
| `err_select_display.v` | 2 × 7485 + 74157 | Window validity check, 7-segment data selection with `Er` override |
| `time_compare_enlight.v` | magnitude comparator + 74138 | In-window test and 8-step marquee decode |
| `bcd_to_7seg.v` | 7448 | BCD → 7-segment decoder, active-high outputs |

## Repository layout

| Path | Description |
| --- | --- |
| `README.md` | English documentation (this file) |
| `README_zhcn.md` | Chinese documentation |
| `timer_top.v` | Top-level module |
| `timer_main.v` | Countdown engine |
| `key_set_timer.v` | Keypad scanning and time setting |
| `err_select_display.v` | Range validation and display data selection |
| `time_compare_enlight.v` | Window comparison and LED marquee |
| `bcd_to_7seg.v` | BCD to 7-segment decoder |
| `tb_timer_top_normal.v` | Functional testbench — legal window `[37, 55]` |
| `tb_timer_top_error.v` | Wide window `[45, 55]` plus illegal window `[10, 30]` (`Er` case) |
| `tb_timer_top_normal.vcd`, `tb_timer_top.vcd` | Waveform databases produced by the two testbenches |
| `timer_top.vcd` | Additional waveform capture retained from earlier runs |
| `wave_normal1.png`, `wave_normal2.png`, `wave_error.png` | Annotated waveform screenshots |
| `.gitignore` | Excludes simulation intermediates (`*.vvp`) and tool build directories |

## Architecture

The six modules connect as follows. Five of them are functional blocks ported from the original
schematic; `bcd_to_7seg` is instantiated four times, once for each static setting digit.

```mermaid
flowchart LR
    CLK(["clk_1khz<br/>1 kHz"])
    RST(["reset"])
    ROW(["row[3:0]<br/>keypad rows"])

    KST["<b>key_set_timer</b><br/>scan + synchroniser<br/>+ presettable digits"]
    TM["<b>timer_main</b><br/>÷1000 → 1 Hz tick<br/>+ BCD countdown"]
    ESD["<b>err_select_display</b><br/>range check<br/>+ 7-segment data select"]
    TCE["<b>time_compare_enlight</b><br/>in-window test<br/>+ ÷100 → 10 Hz marquee"]
    DEC["<b>bcd_to_7seg</b> × 4<br/>7448 decoders"]
    NOR["NOR3<br/>reset gating"]
    INV["NOT<br/>LED driver"]

    CLK --> KST
    CLK --> TM
    CLK --> TCE
    ROW --> KST

    KST -->|"col[3:0]"| COL(["col[3:0]"])
    KST -->|"start_h/l, end_h/l (BCD)"| ESD
    KST -->|"start / end (BCD)"| TCE
    KST -->|"start / end (BCD)"| DEC

    RST --> NOR
    ESD -->|auto_load| NOR
    TM -->|timer_reset| NOR
    NOR -->|"reset_total (active low)"| TM

    TM -->|"timer_h_in / timer_l_in (BCD)"| ESD
    TM -->|"timer_h_in / timer_l_in (BCD)"| TCE

    ESD -->|"timer_h_out / timer_l_out"| DISP(["countdown digits<br/>or 'Er'"])
    DEC -->|"4 × 7-segment"| SEG(["start / end digits"])
    TCE -->|"led_sig[7:0]"| INV
    INV -->|"led_out[7:0]"| LED(["8-way marquee LEDs"])

    classDef src fill:#eef3fd,stroke:#3b6fd4,color:#12233d
    classDef out fill:#eaf7ee,stroke:#3c8f5a,color:#12291b
    class CLK,RST,ROW src
    class COL,DISP,SEG,LED out
```

The same structure as plain text, for readers viewing this file outside GitHub:

```
                    clk_1khz ──┬──────────────┬───────────────┐
                               │              │               │
   row[3:0] ──► key_set_timer ─┼──► start/end (BCD) ──┬──► err_select_display ──► digits / "Er"
                     │         │                      ├──► time_compare_enlight ─► NOT ─► LEDs
                     └─ col[3:0]│                      └──► bcd_to_7seg ×4 ──────► start/end digits
                               │
              reset ──┐        │
        auto_load ────┼──► NOR3 ┴──► reset_total (active low) ──► timer_main ──► timer h/l (BCD)
      timer_reset ────┘
```

Three interconnect paths carry the behaviour of the design:

1. **Countdown → window test → LEDs.** `timer_main` publishes the live BCD value; both
   `err_select_display` and `time_compare_enlight` consume it, so the marquee and the digits always
   agree.
2. **`auto_load` → `reset_total` → `timer_main`.** The unreachable-window flag feeds the NOR3 gate
   that drives the active-low preset.
3. **`timer_reset` → `reset_total`.** The same gate turns the `00` rollover into the reload, which is
   why both paths converge on `reset_total`.

Two glue elements reproduce the original gate-level wiring:

```verilog
assign reset_total = ~(auto_load | reset | timer_reset);  // NOR3
assign led_out     = ~led_sig;                            // inverting LED driver
```

Because `timer_reset` is asserted whenever the counter reads `00`, the NOR3 gate turns an
out-of-range window or a rollover into a synchronous, active-low preset — the counter reloads to 60
instead of sitting at zero.

## Functional description

### Clocking and the countdown

The 1 kHz input clock is divided by a free-running counter. Toggling the divided signal every
500 counts yields a 1 Hz square wave, whose **rising edge is extracted by a two-stage flip-flop
delay** to produce a single-cycle enable pulse `pulse_1hz`. The countdown therefore never uses a
divided clock as a clock — all sequential logic runs on the original 1 kHz clock.

Each `pulse_1hz` performs one BCD decrement:

- unit digit `timer_l_in` decrements normally when non-zero;
- when the unit digit is `0`, it borrows: the unit digit becomes `9` and the tens digit
  `timer_h_in` decrements;
- when the counter reaches `00`, it automatically reloads to `60`.

A low-active `reset_total` synchronously presets the counter to `60`.

### Keypad time setting

The column lines are driven with the constant pattern `4'b1110`, so only the keys in one column are
read at a time. The four row inputs are passed through a two-stage synchroniser and then compared
with a further delayed copy to derive a **rising-edge key event** `key_pressed`. Each key cycles its
own setting value with wraparound:

| Key | Setting | Range |
| --- | --- | --- |
| `row[0]` | `start_h` (tens of the start time) | 0–5 |
| `row[1]` | `start_l` (units of the start time) | 0–9 |
| `row[2]` | `end_h` (tens of the end time) | 0–5 |
| `row[3]` | `end_l` (units of the end time) | 0–9 |

### Window comparison and the marquee

A second divider produces a 10 Hz enable pulse, giving the marquee its stepping rate. Because the
countdown runs from `start` down to `end`, the current value is inside the window when:

```verilog
in_range = (start_time >= end_time) &&
           (current_time <= start_time) &&
           (current_time >= end_time);
```

For example with `start = 50` and `end = 10`, the values 50, 49, … 11, 10 are all inside the window.
While `in_range` is asserted, a 3-bit counter advances on every 10 Hz pulse and is decoded into an
8-bit **one-hot, active-low** pattern; when the countdown leaves the window the counter resets and
all LEDs are driven off.

### Unreachable window and the `Er` indication

```verilog
assign is_error  = ({start_h, start_l} < {end_h, end_l});
assign auto_load = is_error;
```

If the start time is smaller than the end time the window can never be entered, so the design
asserts `auto_load`, which holds the countdown at `60`, and drives the countdown digit tubes with a
hard-coded `Er` pattern instead of a numeric value:

```verilog
localparam [6:0] SEG_ERR_H = 7'b111_1001;  // 'E' on the tens digit
localparam [6:0] SEG_ERR_L = 7'b101_0000;  // 'r' on the units digit
```

The segment encoding is `{g, f, e, d, c, b, a}` with active-high outputs, matching the 7448 decoder
convention.

## Ports and pin assignments

Top-level entity `timer_top` (pin references come from the original MAX II board assignment):

| Port | Dir | Width | Description | Pin |
| --- | --- | --- | --- | --- |
| `clk_1khz` | in | 1 | 1 kHz system clock | `PIN_18` |
| `reset` | in | 1 | External reset push-button | `PIN_20` |
| `row` | in | 4 | Keypad row inputs | `PIN_23, 24, 27, 28` |
| `col` | out | 4 | Keypad column drive | `PIN_29, 30, 31, 32` |
| `timer_h_out` | out | 7 | Countdown tens digit, 7-segment | `PIN_102…104` |
| `timer_l_out` | out | 7 | Countdown units digit, 7-segment | `PIN_88…94` |
| `led_out` | out | 8 | 8-way marquee / status LEDs (active-low) | `PIN_1…8` |
| `start_h_seg` | out | 7 | Start time tens digit | `PIN_140…142` |
| `start_l_seg` | out | 7 | Start time units digit | `PIN_130…132` |
| `end_h_seg` | out | 7 | End time tens digit | `PIN_120…122` |
| `end_l_seg` | out | 7 | End time units digit | `PIN_110…112` |

## Verification

Verification combines simulation with two directed testbenches and a synthesis check.

| Testbench | Phases | Scenarios exercised |
| --- | --- | --- |
| `tb_timer_top_normal.v` | 6 | Reset and preset to 60; release and observe 60→59→58; configure the legal window `start=55, end=37`; observe the countdown crossing the window with the marquee active; count down to `00` and observe `timer_reset` followed by the reload to 60; confirm the second cycle begins |
| `tb_timer_top_error.v` | 7 | Reset; countdown; configure the wide legal window `start=55, end=45`; observe window crossing; observe `00` and the automatic reload; configure the illegal window `start=10, end=30` (which is `start < end`); confirm `is_error` asserts and the `Er` display and blanked LEDs remain stable |

Both testbenches print a per-phase snapshot of the internal state, which makes the expected
behaviour directly checkable from the console:

```
--- Phase 4: Watch countdown crossing window [55..37] ---
[84497000]  expect ~52  -> inside window | start= 5 5 end= 3 7 timer= 5 2 | err=0 range=1 led=01111111

--- Phase 6: Configure start=10, end=30 (illegal) ---
[636137000] t=10 end=30 set  => is_error should be 1 | start= 1 0 end= 3 0 timer= 6 0 | err=1 range=0 led=11111111
```

**Methodology note.** The testbenches are directed and observational: they drive stimulus, print a
state snapshot at each phase, and dump a VCD for waveform inspection. They deliberately do **not**
contain self-checking assertions or a scoreboard, so the pass/fail judgement is made by inspecting
the printed snapshots and the waveforms rather than automatically. Making these checks self-checking
is the first item in the future-work list below.

### Synthesis check

The same RTL was synthesised in Quartus II 9.1 SP2 for an Altera MAX II device:

| Result | Value |
| --- | --- |
| Analysis & Synthesis | Successful |
| Family / top-level entity | MAX II / `timer_top` |
| Total logic elements | 172 |
| Total pins | 60 |

## Reproducing the simulation

Verified with **Icarus Verilog 12.0**. Each testbench is compiled on its own, since both instantiate
the same `timer_top` with different stimulus:

```bash
# Functional testbench — legal window [37, 55]
iverilog -g2005 -o tb_normal.vvp \
    timer_top.v timer_main.v err_select_display.v \
    time_compare_enlight.v key_set_timer.v bcd_to_7seg.v \
    tb_timer_top_normal.v
vvp tb_normal.vvp
gtkwave tb_timer_top_normal.vcd

# Error / wide-window testbench — [45, 55] and illegal [10, 30]
iverilog -g2005 -o tb_error.vvp \
    timer_top.v timer_main.v err_select_display.v \
    time_compare_enlight.v key_set_timer.v bcd_to_7seg.v \
    tb_timer_top_error.v
vvp tb_error.vvp
gtkwave tb_timer_top.vcd
```

The testbenches use `CLK_PERIOD = 10`, so one logical countdown second corresponds to 1000 clock
cycles, or 10 µs of simulated time; a full run covering two complete countdown cycles completes in
about 0.64 s of simulated time.

Two naming details that are intentional, not mistakes: the error testbench declares its module as
`tb_timer_top` and writes its waveform to `tb_timer_top.vcd`, both carried over from the original
file name.

## Waveform captures

Both testbenches call `$dumpvars` on their whole scope, so every internal signal is available in the
VCD. All three captures below plot the same signal set:

`clk_1khz`, `reset`, `start_h`/`start_l`, `end_h`/`end_l`, `in_range`, `is_error`, `auto_load`,
`reset_total`, `timer_h`/`timer_l`, `timer_reset_s`, `led_cnt`, `led_sig`, `led_out`

These map onto the observation wires declared by the testbenches as follows:

| Signal | Width | Meaning |
| --- | --- | --- |
| `clk_1khz` | 1 | The 1 kHz clock — the reference for reading every other trace |
| `reset` | 1 | External reset input, active high |
| `start_h`, `start_l`, `end_h`, `end_l` | 4 each | The programmed window, in BCD |
| `timer_h`, `timer_l` | 4 each | The live countdown value, in BCD |
| `in_range` | 1 | High while the countdown is inside `[end, start]` |
| `is_error` | 1 | High when the programmed window is unreachable (`start < end`) |
| `auto_load` | 1 | The unreachable-window reload request (equals `is_error`) |
| `reset_total` | 1 | The gated active-low preset, `~(auto_load \| reset \| timer_reset)` |
| `timer_reset_s` | 1 | Rollover pulse, asserted while the countdown reads `00` |
| `led_cnt` | 3 | Marquee step counter — advances once per 10 Hz tick, only while `in_range` |
| `led_sig` | 8 | Marquee pattern, active low: one bit at 0 while `in_range`, all ones outside |
| `led_out` | 8 | `~led_sig`, active high — a bit is 1 where an LED is lit |

Two conventions make the LED buses easy to read: `led_sig` is the internal active-low pattern (one
walking zero inside the window) and `led_out` is its inverse, which is what actually drives the LEDs
(one walking one). When the marquee is stopped, `led_sig` is `11111111` and `led_out` is `00000000` —
every LED dark.

### Reading the timing

Three time scales appear in the traces and are worth keeping in mind: the clock period is 10 ns, one
logical countdown second is 1000 clocks (10 µs of simulated time), and the marquee advances once per
100 clocks (1 µs of simulated time). So a trace showing the countdown stepping from one BCD value to
the next is 10 µs wide, and eight marquee positions occupy 8 µs.

### 1. Marquee start and stop — `wave_normal1.png`

![in_range rising at 55 and falling as the countdown passes 37](wave_normal1.png)

**Scenario:** the legal window `start=55, end=37`. This is the capture that shows `in_range` going
0 → 1 → 0 together with the LED response.

| Time | Event | Observable |
| --- | --- | --- |
| 24.497 µs | Window programmed to `start=55, end=37` | `start_h/l=55`, `end_h/l=37`, `in_range=0`, `led_sig=11111111` |
| 54.497 µs | Countdown reaches 55 — **window entry** | `in_range` rises; `led_sig` leaves `11111111` and `led_cnt` starts advancing |
| 84.497 µs | Countdown at 52 | `in_range=1`, marquee has stepped away from its start position |
| 234.497 µs | Countdown at 37 — the window's end value | Still `in_range=1` on this cycle |
| 254.497 µs | Countdown at 35 — **window exit** | `in_range` falls; `led_cnt` resets, `led_sig` returns to `11111111`, `led_out` to `00000000` |

**What to look for:** `in_range` is high for every countdown value from 55 down to 37 inclusive, and
low from 36 downward. While it is high, `led_sig` holds a single walking zero (mirrored by a single 1
in `led_out`) and `led_cnt` counts up. As soon as the countdown passes the end value the marquee
counter resets and the LEDs go dark — the blanking is driven by the window test alone and does not
wait for the countdown to reach `00`.

### 2. Rollover and reload — `wave_normal2.png`

![timer_reset_s pulsing as the countdown rolls from 00 back to 60](wave_normal2.png)

**Scenario:** the same legal window, watched as the countdown reaches `00` and reloads. This is the
capture that shows the `00 → 60` transition and the `timer_reset_s` pulse that causes it.

| Time | Event | Observable |
| --- | --- | --- |
| 604.497 µs | Countdown reaches `00` | `timer_reset_s` asserts and `reset_total` is pulled low; the counter is preset to `60` on the very next clock edge, so the phase snapshot printed at this timestamp already reads `60` |
| 614.497 µs | One countdown second later | `timer_h/l=59` — counting has resumed normally |
| 644.497 µs | Second cycle under way | Countdown continues past `56` |

**What to look for:** the `00` state is short-lived, which is the point of this capture. `timer_reset_s`
is combinational on the countdown reading `00`, so it stays high for exactly one clock period (1 µs out
of the 10 µs countdown step) before the preset lands — **zoom in to see the pulse**. `in_range` stays
low throughout, because the window is `[37, 55]` and neither `60` nor `00` lies inside it; that is why
`led_sig` remains all ones here.

### 3. Unreachable window — `wave_error.png`

![is_error high: the countdown is held at 60 and the LED bus is blanked](wave_error.png)

**Scenario:** the illegal window `start=10, end=30` — the `start < end` case. The earlier phases of
the same testbench provide context, but this capture is centred on the region where `is_error=1`.

| Time | Event | Observable |
| --- | --- | --- |
| 24.407 µs | *(context)* legal window `start=55, end=45` programmed | `is_error=0` |
| 74.407 µs | *(context)* window entered, marquee running | `in_range=1` |
| 624.407 µs | *(context)* countdown reaches `00` and reloads | `timer_reset_s` pulse, back to `60` |
| 636.137 µs | Illegal window `start=10, end=30` programmed | **`is_error` rises**; `auto_load` follows it |
| 636.137 µs onward | `auto_load` reaches the NOR3 gate | `reset_total` held low for as long as the illegal window stands |
| 686.137 µs | Held to the end of the run | `is_error=1`, `in_range=0`, `timer_h/l=60` frozen, `led_sig=11111111` / `led_out=00000000` |

**What to look for:** `is_error` high with `auto_load` following it, and `reset_total` pinned low
throughout. Because here the preset is asserted continuously rather than as a single pulse,
`timer_h`/`timer_l` stay frozen at `6`/`0` instead of counting down. `in_range` never rises, so the
marquee stays stopped and the whole LED bus stays dark, and the countdown digit outputs carry the
hard-coded `E` / `r` segments instead of a number.

The raw data behind these screenshots is in `tb_timer_top_normal.vcd`,
`tb_timer_top_error.vcd` and `tb_timer_top.vcd`; they can be opened directly in GTKWave.

## Tools and environment

| Tool | Version | Role |
| --- | --- | --- |
| Icarus Verilog | 12.0 | RTL elaboration, simulation, VCD generation |
| GTKWave | — | Waveform inspection |
| Quartus II | 9.1 SP2 | Synthesis and pin assignment targeting MAX II |
| Language | Verilog-2001 | ANSI-style port declarations, synthesizable subset |

## Known limitations and future work

- **Testbenches are not self-checking.** Adding assertions or a scoreboard would turn the current
  manual inspection into an automatic regression.
- **Only one keypad column is scanned** (`col = 4'b1110`), which supports four keys; a full 4×4 scan
  would require a column counter and decoding of the active column.
- **The reload value is fixed at 60.** A user-programmable preset would need additional registers and
  comparison logic in the countdown engine.
- **Debouncing is a two-stage synchroniser with edge detection only** — sufficient for simulation,
  but a hardware keypad would benefit from a timed filter.
- **The reload path and the `auto_load` path both act through the same preset**, so the `Er` state and
  a normal rollover are distinguished only by the displayed value and the LED state.
