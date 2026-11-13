# [AI 검증용 학습자료] Basys3 통합 시스템 — 스톱워치·시계·초음파(HC-SR04)·온습도(DHT11)·UART/FIFO

> 버전: v1.0 (2026-11-06)
> 근거 자료: ① 수업 노션 페이지 「2교과 verilog」(UART·FIFO·SR04·DHT11·스톱워치 정리, 문서/발표 작성 기준, 검증 강의) ② Vivado 프로젝트 `20261030_PORJECT_SENSOT_UART` 의 RTL 24개 파일 + 테스트벤치 `tb_sr04_top.v` + `SR04_시뮬레이션_발표.md`
> 이 문서의 모든 수치는 **코드에서 직접 계산·확인한 값**이다. 코드로 확인할 수 없는 내용은 `[미확인]`, 검토가 필요한 의심 지점은 `[검토 필요]`로 표시했다.

---

## 0. 검증 AI에게 주는 지시 (이 블록을 먼저 읽을 것)

너는 이 프로젝트의 **독립 검증자(Verification Engineer)** 역할을 한다. 설계자는 전기전자공학 전공 학생이며, 이 프로젝트는 수업(2교과: Verilog / UVM / 칩설계) 팀 프로젝트다.

1. 이 문서를 프로젝트의 **사양서(spec)이자 설계 의도**로 학습한다. 이후 질문에 코드·파형·보고서가 함께 오면, 이 문서의 의도와 실제 동작이 일치하는지 판정한다.
2. 판정은 반드시 다음을 구분해서 쓴다.
   - **사실**: 코드/파형에서 직접 확인되는 것 (파일명·라인·신호명으로 근거 제시)
   - **추정**: 근거가 부분적이거나 하드웨어/데이터시트 조건에 따라 달라지는 것
   - **확인 불가**: 주어진 자료로 판단할 수 없는 것 (무엇이 더 필요한지 명시)
3. 칭찬이나 과장 없이 쓴다. 장점보다 **오류·모순·실패 가능성**을 우선 보고한다.
4. 검증 결과는 §9의 출력 형식(Pass/Fail 표 + 근거 + 재현 시나리오 + 수정 제안)을 따른다.
5. "버그"라고 단정하려면 **구체적인 입력/상태 → 잘못된 출력**의 재현 시나리오를 제시해야 한다. 재현 시나리오가 없으면 "의심" 등급으로만 보고한다.
6. Verilog 문법 자체보다 **이 설계의 동작·타이밍·예외 처리**를 본다. (수업 발표 기준: "문법은 알고 내 코드는 모른다는 전제로 설명")

---

## 1. 프로젝트 개요

### 1.1 목적
Basys3(Xilinx Artix-7, 100 MHz 시스템 클럭) 위에서 **4가지 기능 모드**를 하나의 탑 모듈로 통합하고, 보드 버튼/스위치와 **PC UART 명령** 두 경로로 제어하며, 결과를 **4자리 FND**와 **UART 문자열**로 출력한다.

| 모드 코드 `active_mode` | 기능 | FND 표시 | UART 상태 출력 |
|---|---|---|---|
| `3'b000` | 스톱워치 (업/다운 카운트, 랩타임) | MM.SS 또는 HH.MM (SW4로 전환) | `0:HH:MM:SS.CC` |
| `3'b001` | 시계 (12:00 시작, 시간 설정 기능) | 동일 | `1:HH:MM:SS.CC` |
| `3'b010` | HC-SR04 초음파 거리 측정 | `d` + 3자리 cm | `distance : NNNcm` |
| `3'b011` | DHT11 온습도 측정 | `H` + 습도 / `t` + 온도 (SW4) | `humidity:NN%` + `temperature: NNC` |
| `3'b1xx` | 예약(미사용) | 전부 꺼짐 | 없음 |

LED[2:0] = 현재 `active_mode` 값 그대로 표시.

### 1.2 탑 모듈 입출력 (`integrated_system_top`)

| 포트 | 방향 | 폭 | 용도 |
|---|---|---|---|
| `clk` | in | 1 | 100 MHz |
| `rst` | in | 1 | BTNC — **선택 리셋** (현재 모드만 리셋, 시간 모드에서만 유효) |
| `btnR/L/U/D` | in | 1 | 모드별 기능 버튼 (§1.4) |
| `sw` | in | 16 | SW0~2 모드 선택, SW3 랩 표시, SW4 표시 전환, SW5 시계 설정, SW15 전역 리셋 |
| `echo` | in | 1 | HC-SR04 Echo |
| `trigger` | out | 1 | HC-SR04 Trig |
| `dht11_io` | inout | 1 | DHT11 단일 데이터선 (Low 구동 / High-Z만 사용) |
| `rx` / `tx` | in/out | 1 | USB-UART (9600 bps, 8N1) |
| `fnd_com` | out | 4 | FND 자리 선택 (Active Low) |
| `fnd_font` | out | 8 | 세그먼트 {dp,g,f,e,d,c,b,a} (Active Low) |
| `led` | out | 3 | 현재 모드 표시 |

`[미확인]` 프로젝트의 `constrs_1`에 XDC 파일이 등록돼 있지 않다(.xpr 확인). 핀 배치, `dht11_io`의 PULLUP 설정 여부는 이 자료로 확인할 수 없다.

### 1.3 스위치 기능

| 스위치 | 기능 | 비고 |
|---|---|---|
| SW[2:0] | 모드 선택 | 각각 `reset_input_filter`(2-FF + 10 ms 안정 판정) 통과 후 사용 |
| SW3 | 스톱워치 랩타임 표시 | 랩이 한 번이라도 저장됐을 때만 랩 값 표시 |
| SW4 | 표시 전환 | 시간 모드: 0=SS.CC(초·센티초), 1=HH.MM / DHT11: 0=습도, 1=온도 |
| SW5 | 시계 시간 설정 진입 | 시계 모드일 때만 유효 (`w_watch_setting = is_watch & sw[5]`). 모듈 포트 이름은 `sw2`(초기 설계 흔적) |
| SW15 | 전역 리셋 | **레벨 감지**: ON인 동안 계속 리셋 유지 |

### 1.4 버튼 / UART 명령 매핑 (`integrated_control_unit`)

| 모드 | btnR / UART `r` | btnL / UART `c` | btnU / UART `u` | btnD | UART `s` |
|---|---|---|---|---|---|
| 스톱워치 | Run/Stop | Clear | 업/다운 모드 토글 | Lap 저장 | 상태 1회 전송 |
| 시계 | 오른쪽 자리로 이동 | 왼쪽 자리로 이동 | 값 +1 | 값 -1 | 상태 1회 전송 |
| SR04 | 측정 시작 | - | - | - | 상태 1회 전송 |
| DHT11 | 측정 시작 | - | - | - | 상태 1회 전송 |

- UART `1`/`2`/`3`/`4` → 모드 000/001/010/011로 원격 전환.
- 대소문자 모두 인식 (`R/r`, `C/c`, `U/u`, `S/s`).
- `btnD`(Lap, 시계 -1)에 대응하는 UART 명령은 **없다**.
- 모드 결정 우선순위: **물리 스위치 값이 바뀐 순간 > UART 모드 명령**. UART로 바꾼 모드는 스위치를 다시 움직이기 전까지 유지된다. 전역 리셋 시에는 스위치 값으로 복귀.

### 1.5 UART 출력 형식 (`ascii_sender`)

| 이벤트 | 전송 문자열 | 바이트 수 |
|---|---|---|
| `r/c/u` 명령 수신 | 명령 문자 에코 + `\r\n` (예: `r\r\n`) | 3 |
| `1~4` 모드 명령 | 해당 숫자 에코 + `\r\n` | 3 |
| 시간 모드 상태 | `M:HH:MM:SS.CC\r\n` (M=`0` 스톱워치, `1` 시계) | 15 |
| SR04 상태 | `distance : NNNcm\r\n` (앞자리 0 생략, 마지막 자리는 유지) | 15~18 |
| DHT11 상태 | `humidity:NN%\r\ntemperature: NNC\r\n` (앞자리 0 생략) | 28~34 |

- 시간 모드에서는 **0.5초마다 자동으로 상태 전송** (`periodic_status`). 단, 송신기가 바쁘거나 RX FIFO에 명령이 남아 있으면 그 회차는 **건너뛴다**(재시도 없음).
- 센서 모드에서는 자동 전송 없음. `s` 명령으로만 전송.
- 9600 bps 8N1 → 1바이트 = 10비트 = 약 1.042 ms. 시간 상태 15바이트 ≈ 15.6 ms, DHT11 상태 최대 34바이트 ≈ 35.4 ms.

### 1.6 성능·범위 요약

| 항목 | 값 | 근거 |
|---|---|---|
| 스톱워치/시계 분해능 | 10 ms (센티초) | `tick_gen_100hz`: 100 MHz / 1,000,000 |
| 시간 범위 | 00:00:00.00 ~ 23:59:59.99 | hour TIMES=24 |
| SR04 거리 | 0 ~ 511 cm (9비트), 분해능 1 cm(버림) | `distance = floor(echo_us / 58)` |
| SR04 측정 간격 | 최소 60 ms (start→start) | `MIN_PERIOD_US = 60_000` |
| SR04 타임아웃 | WAIT 36 ms, DISTANCE 36 ms | `TIMEOUT_TICKS = 36_000` |
| DHT11 측정 간격 | 최소 1 s (리셋 직후 포함) | `MIN_PERIOD_US = 1_000_000` |
| DHT11 단계별 타임아웃 | 150 µs | `TIMEOUT_US = 150` |
| DHT11 표시 | 정수부만 (습도 %RH, 온도 °C) | `humidity[15:8]`, `temperature[15:8]` |
| UART | 9600 bps, 8N1, 16배 오버샘플링 | `F_COUNT = 100e6/(9600*16) = 651` |
| RX FIFO / TX FIFO 깊이 | 16 / 4 바이트 | `fifo #(.DEPTH(16))` / 기본값 4 |

---

## 2. 관련 이론 (설계 판단의 근거)

### 2.1 Tick(Enable) 방식 vs 분주 클럭
- 이 설계의 기본 원칙: **모든 순차 로직은 100 MHz 단일 클럭**으로 동작하고, 느린 동작은 1클럭 폭 `tick` 펄스를 enable로 써서 만든다. (예: 100 Hz tick, 1 µs tick, UART 16× baud tick)
- 이유: 분주 클럭을 다른 플립플롭의 클럭으로 쓰면 새로운 클럭 도메인이 생겨 CDC·타이밍 분석 문제가 생긴다.
- 예외: `btn_debounce`의 `clk_1mhz`, `fnd_controller`의 `o_clk_1600hz`는 **로직 출력이 다른 always 블록의 클럭으로 쓰인다** → §8 검토 항목.

### 2.2 FSM (Moore / Mealy, 2-프로세스 구조)
- 상태 레지스터(`c_state <= n_state`, 순차) + 다음상태/출력 조합 로직(`always @(*)`)을 분리하는 구조를 전 모듈에서 사용.
- `_reg`/`_next` 쌍: 값을 기억해야 하거나 클럭에 맞춰 출력해야 하는 신호는 `_reg`로 저장하고 조합 로직에서는 `_next`만 계산.
- Moore: 출력이 상태에만 의존 (예: 스톱워치 `run_stop`). Mealy: 출력이 입력에도 의존해 1클럭 빠름.
- 수업에서 TX를 ASM 차트로 설계(상태=원, Moore 출력=사각형, 조건=마름모, Mealy 출력=캡슐형).

### 2.3 블로킹 / 논블로킹
- 조합 로직: `=` (블로킹, 순서대로 평가). 순차 로직: `<=` (논블로킹, 동시 갱신).
- 이 설계의 조합 always 블록은 모두 블록 시작에서 기본값을 대입해 래치 생성을 막는 패턴을 쓴다.

### 2.4 버튼 디바운스 + 상승 엣지 검출
- 기계식 버튼은 눌림/떼임 순간 수 ms 동안 채터링이 생긴다.
- 방법: 느린 샘플링으로 8비트 시프트 레지스터(SIPO)에 버튼 값을 넣고, 8비트 모두 1일 때만 눌림으로 판정(8입력 AND). 그 결과를 1클럭 지연시킨 값과 비교해 `~prev & now` → 1클럭 펄스.

### 2.5 메타스테빌리티와 동기화기
- 클럭과 무관하게 변하는 외부 신호(echo, dht11_io, 스위치, 버튼, rx)를 플립플롭이 셋업/홀드 구간에 샘플링하면 출력이 불안정한 중간값에 머물 수 있다(메타스테이블).
- 단일 비트: 2-FF 동기화기로 확률을 낮춘다. 다중 비트: 비트별 도착 시간 차(skew) 때문에 동기화기로 부족 → 비동기 FIFO 사용 (수업 노트).
- 이 설계에서 2-FF 적용: echo(SR04), dht11_io(DHT11, `ASYNC_REG` 속성), SW/BTNC(`reset_input_filter`). **rx와 btnR/L/U/D는 2-FF 없이 사용** → §8.

### 2.6 UART 프로토콜
- 비동기 직렬 통신: 클럭선 없이 송수신 양쪽이 같은 baud rate를 미리 약속.
- 프레임(8N1): IDLE=1 → Start bit 0 → Data 8비트 (**LSB first**) → Stop bit 1.
- 9600 bps → 1비트 = 104.17 µs.
- RX는 송신 클럭과 위상이 맞지 않으므로 비트 **중앙**에서 샘플링해야 한다. 그래서 baud의 16배 tick을 쓰고, Start 하강 검출 후 8 tick(반 비트) 뒤 = Start 중앙, 이후 16 tick마다 = 각 데이터 비트 중앙에서 샘플링.
- 16배 오버샘플링에서 시작점 검출 오차는 최대 1 tick(1/16 비트)이다.
- 패리티 비트는 이 설계에서 쓰지 않는다(N).

### 2.7 동기식 FIFO
- push → `wptr` 위치에 쓰고 +1, pop → `rptr` 위치를 읽고 +1.
- `wptr == rptr`는 empty와 full 두 경우가 모두 가능하므로, 포인터 비교 대신 **full/empty 플래그를 FSM으로 관리**한다.
  - push only: 다음 wptr == rptr 이면 full
  - pop only: 다음 rptr == wptr 이면 empty
  - push+pop 동시: full이면 pop만, empty면 push만, 그 외 둘 다 진행
- 깊이는 2의 거듭제곱 → 포인터가 자연 오버플로로 순환.
- 수업 노트: 비동기 출력 읽기(조합 출력)는 BRAM/LUTRAM 합성 결과가 달라진다(조합 출력/순차 출력 차이).

### 2.8 FND(7-세그먼트) 다이내믹 구동
- 4자리가 세그먼트선을 공유하므로 한 번에 1자리만 켜고 빠르게 순환 → 잔상 효과.
- COM, 세그먼트 모두 Active Low. `8'hC0`='0', `8'hFF`=전부 꺼짐, `8'h7F`=점(dp)만 켬.
- BCD 0000~1001만 숫자로 쓰고 남는 코드 1110(점만), 1111(꺼짐)을 표시 제어용으로 재활용 (수업 노트 「BCD 가운데 도트 점멸」).

### 2.9 Double Dabble (이진 → BCD)
- 이진수를 MSB부터 한 비트씩 BCD 레지스터로 시프트하면서, 시프트 전에 각 BCD 자리 값이 5 이상이면 3을 더한다(Add-3).
- `ascii_sender`는 9비트 입력을 **9클럭에 걸쳐 순차 변환** (조합 `/`, `%` 회로를 피하기 위함).
- 반면 FND 쪽 `digit_splitter`, `sensor_fnd_controller`는 `/`, `%` 조합 연산을 그대로 쓴다(합성기가 상수 나눗셈 회로 생성).

### 2.10 HC-SR04 초음파 센서
- Trig에 10 µs 이상 High 펄스 → 센서가 40 kHz 8주기 버스트 송신 → 반사파가 돌아오는 왕복 시간만큼 Echo High.
- 거리(cm) = Echo 시간(µs) / 58 (음속 약 340 m/s, 1 cm 왕복 ≈ 58.8 µs → 정수 58 사용).
- 측정 주기 60 ms 이상 권장(잔향 방지). 물체가 없으면 Echo가 약 38 ms 동안 High.
- 수업 노트: trig 마진 약 10% 고려, Echo 입력 동기화기 필요, 나눗셈(`/58`)은 불안정하므로 카운터 방식 사용.

### 2.11 DHT11 온습도 센서
- 단일 데이터선 **반이중(half duplex)**, 평소 풀업으로 High.
- MCU: 18 ms 이상 Low 출력 → 해제(High-Z).
- 센서 응답: 80 µs Low → 80 µs High → 40비트 데이터.
- 각 비트: 50 µs Low 후 High 유지 시간으로 판별 (약 26~28 µs = 0, 약 70 µs = 1). 이 설계는 **40 µs 이상이면 1**로 판정.
- 데이터 40비트, **MSB first**: 습도 정수 8 + 습도 소수 8 + 온도 정수 8 + 온도 소수 8 + 체크섬 8. 체크섬 = 앞 4바이트 합의 하위 8비트.
- FPGA 쪽은 High를 능동 구동하지 않고 **Low 또는 High-Z만** 출력(3-state). 센서와 버스 충돌 방지.
- 측정 간격 1 s 이상.

### 2.12 리셋 설계
- 비동기 리셋 assert는 즉시 가능하지만 **release(해제)**가 클럭 엣지 근처에서 일어나면 플립플롭마다 해제 시점이 달라질 수 있다(recovery/removal).
- 이 설계는 리셋 출력을 **negedge clk**에서 갱신해 해제 시점을 posedge에서 반 주기 떨어뜨렸다(§4.2).

---

## 3. 계층 구조와 데이터 흐름

### 3.1 모듈 계층

```
integrated_system_top
├─ reset_input_filter ×3        (SW0~2 모드 스위치 필터)
├─ reset_controller             (전원 리셋 / SW15 전역 / BTNC 선택 리셋)
│   └─ reset_input_filter ×3   (SW0상당, SW15, BTNC)
├─ btn_debounce ×4             (R, L, U, D)
├─ integrated_control_unit      (모드별 버튼·UART 명령 분배, 조합)
├─ control_unit                 (스톱워치 FSM: STOP/RUN/CLEAR/MODE)
├─ stopwatch_datapath
│   ├─ tick_gen_100hz
│   └─ tick_counter ×4         (msec 100, sec 60, min 60, hour 24, 업/다운)
├─ watch_control_unit
│   └─ watch_setting_fsm       (NORMAL / SET_msec / SET_sec / SET_min / SET_hour)
├─ watch_datapath_sw2
│   ├─ tick_gen_100hz
│   └─ watch_editable_counter ×4 (hour 리셋값 12)
├─ lap_time
├─ fnd_controller_stopwatch_watch
│   ├─ clk_div_1600hz, counter_8, decoder_2x4
│   ├─ digit_splitter ×4, dot_comparator
│   ├─ mux_8x1 ×2, mux_2x1, bcd
├─ watch_fnd_blink              (설정 중인 2자리 깜빡임 오버레이)
├─ sr04_top
│   ├─ SR04_sensor             (IDLE/START/WAIT/DISTANCE/STOP)
│   └─ baud_tick_gen_sr04      (1 µs tick, enable/clear 있음)
├─ baud_tick_gen_dht11          (1 µs tick, 항상 enable)
├─ dht11_controller             (8상태 + 단계별 타임아웃)
├─ sensor_fnd_controller        (센서 값 FND 표시, 자체 스캔)
├─ uart_fifo_loopback
│   ├─ uart_rx, uart_tx, baud_tick_gen (9600×16)
│   └─ fifo ×2 (RX 16, TX 4) ─ register_file + fifo_control_unit
├─ ascii_decoder                (수신 바이트 → 명령 펄스)
└─ ascii_sender                 (상태/에코 문자열 생성 → TX FIFO push)
```

### 3.2 데이터 흐름 (텍스트 블록 다이어그램)

```
[SW0~2]─filter─┐                    ┌─[UART '1'~'4']
               ▼                    ▼
          active_mode_reg (스위치 변경 우선) ──► LED, 모든 MUX의 select
               │
[btnR/L/U/D]─debounce─► integrated_control_unit ◄─ ascii_decoder ◄─ RX FIFO ◄─ uart_rx ◄─ rx
                          │  │  │  │
          ┌───────────────┘  │  │  └──────────────► dht11_start ─► dht11_controller ◄─► dht11_io
          ▼                  │  └─────────────────► sr04_start  ─► sr04_top ─► trigger / ◄─ echo
  control_unit ─► stopwatch_datapath ─► lap_time ─┐
                     ▼                            │
  watch_control_unit ─► watch_datapath_sw2 ───────┤ (watch_select로 선택)
                                                  ▼
                         fnd_controller_stopwatch_watch ─► watch_fnd_blink ─┐
                         sensor_fnd_controller ─────────────────────────────┤
                                                                            ▼
                                                    최종 FND MUX (time / sensor / off) ─► fnd_com, fnd_font

  상태 데이터 MUX (32비트, active_mode로 선택) ─► ascii_sender ─► TX FIFO ─► uart_tx ─► tx
  0.5 s 주기 카운터(시간 모드만) ─► periodic_status ─┘
```

### 3.3 32비트 상태 데이터 패킹 (`w_selected_status`)

| 모드 | 구성 | 비트 위치 |
|---|---|---|
| 000 / 001 | `{8'b0, hour(5), min(6), sec(6), msec(7)}` | hour=[23:19], min=[18:13], sec=[12:7], msec=[6:0] |
| 010 | `{23'b0, distance(9)}` | distance=[8:0] |
| 011 | `{humidity(16), temperature(16)}` | 습도 정수=[31:24], 습도 소수=[23:16], 온도 정수=[15:8], 온도 소수=[7:0] |
| 그 외 | 0 | - |

`ascii_sender`는 이 비트 위치에서 잘라 변환한다.

---

## 4. 모듈별 역할과 설계 원리

각 모듈: **역할 → 동작 → 설계 이유 → 검증 포인트** 순서.

### 4.1 `integrated_system_top`
- **역할**: 모든 서브모듈 연결, 모드 레지스터, FND/상태 MUX, UART 흐름 제어, 0.5 s 주기 상태 요청.
- **모드 레지스터**: `active_mode_reg`. 전역 리셋 중에는 스위치 값 로드. 그 외에는 `w_sw_mode != sw_mode_prev_reg`(필터된 스위치가 바뀐 클럭)일 때 스위치 값, 아니면 `mode_sel_valid`일 때 UART 값.
- **UART 수신 흐름 제어**:
  `decode_enable = rx_not_empty && sender_ready && !decode_gap`, `decode_gap <= decode_enable`.
  - 이유: decoder가 바이트를 pop한 클럭(cycle0) 다음 엣지에 명령 펄스가 레지스터에 올라오고, sender는 그 다음 엣지(edge2)에야 IDLE→SEND로 바뀌어 `ready`가 0이 된다. cycle1에서 `ready`가 아직 1이므로 gap이 없으면 두 번째 바이트를 바로 pop해서 sender가 처리하지 못하는 명령 펄스가 생긴다. gap으로 1클럭을 막는다.
  - 결과: sender가 문자열을 보내는 동안 RX 바이트는 FIFO에 쌓여 대기한다.
- **주기 상태 요청**: `period_cnt_reg`가 0~49,999,999를 세고(0.5 s), 마지막 값에서 `sender_ready && RX FIFO 비어 있음`이면 1클럭 펄스.
- **FND 최종 MUX**: 시간 모드 → 시간 FND 경로(blink 적용 후), 센서 모드 → 센서 FND, 나머지 → `com=1111, font=FF`.
- **검증 포인트**
  - 스위치 변경과 UART 모드 명령이 같은 클럭에 오면 스위치가 이긴다.
  - 모드를 바꿔도 다른 모드의 카운터는 계속 동작한다(스톱워치 RUN 중 센서 모드로 가도 스톱워치는 계속 셈).
  - 0.5 s 주기 요청이 건너뛰어지는 조건.

### 4.2 `reset_controller` + `reset_input_filter`
- **reset_input_filter**: 2-FF 동기화 후, 새 값이 `STABLE_CYCLES` 클럭 연속 유지돼야 출력 변경. 기본 1,000,000 = 10 ms. (초기값을 reg 선언에서 0으로 줌 — FPGA 초기화(GSR)에 의존)
- **reset_controller 정책**
  - 전원 투입 후 16클럭 POR(`por_count`) → 전역 리셋.
  - SW15 ON(필터 후) → 전역 리셋을 **유지**(레벨).
  - BTNC 상승 엣지(필터 후) 1회 → 현재 모드(`sw0_clean`: 1=스톱워치, 0=시계)만 1클럭 리셋 펄스. 단 `USE_RESET_ENABLE=1`이고 `reset_enable = w_time_mode`이므로 **센서 모드에서는 BTNC 무시**.
  - 출력: `rst_shared`(전역: 디바운서, FND, 센서, UART 등), `rst_watch`, `rst_stopwatch`.
  - 탑에서 `sw0` 입력은 실제 스위치가 아니라 `w_old_sw0 = ~is_watch`이며 `SW0_STABLE_CYCLES=1`(이미 필터된 신호라 추가 지연 없음).
- **설계 이유**: 모드 스위치를 바꾸기만 해서는 리셋이 걸리지 않게 하고(이전 설계의 문제 해결 흔적), 시계를 리셋하지 않고 스톱워치만 초기화할 수 있게 함. 리셋 출력을 negedge에서 갱신해 해제 시점을 posedge에서 떨어뜨림.
- **검증 포인트**: BTNC 누른 채 모드 전환 시 다른 모드가 리셋되지 않는지, SW15 ON 동안 FND·UART 상태, 센서 모드에서 BTNC 무반응.

### 4.3 `btn_debounce`
- **동작**: `F_COUNT=1000` 카운터로 1000클럭(10 µs)마다 1클럭 펄스 `clk_1mhz` 생성 → 이 신호를 **클럭으로** 8비트 시프트 레지스터 구동 → `&q_reg` → 100 MHz로 상승 엣지 검출 → 1클럭 `o_btn`.
- 실제 판정 조건: 버튼이 약 8샘플 × 10 µs = 약 80 µs 연속 High.
- 사실: 신호 이름·주석은 "1 MHz"지만 실제 샘플 주기는 100 kHz(10 µs). 노션의 수업 버전은 `F_COUNT=100`(1 MHz)이다.
- **검증 포인트**: §8-A (분주 펄스를 클럭으로 사용), 채터링 지속시간(일반적으로 수 ms)에 비해 80 µs 판정 창이 충분한지.

### 4.4 `integrated_control_unit` (순수 조합)
- UART 명령 우선순위 R > C > U > S로 하나만 선택 → 모드별 case로 버튼 펄스와 OR하여 각 기능 펄스로 분배.
- 사실: `ascii_decoder`는 한 클럭에 최대 하나의 명령만 내므로 우선순위 로직이 실제로 경합을 해소하는 경우는 없다.
- 모든 출력 기본값 0 → 해당하지 않는 모드에서는 펄스가 나가지 않음.

### 4.5 `control_unit` (스톱워치 FSM)
- 상태: `STOP(00) / RUN(01) / CLEAR(10) / MODE(11)`.
  - STOP: run_stop 펄스 → RUN, clear → CLEAR, mode → MODE (우선순위 run_stop > clear > mode).
  - RUN: `run_stop=1`(Moore), run_stop 펄스 → STOP. **RUN 중 clear/mode 입력은 무시**.
  - CLEAR: `clear=1` 1클럭 → STOP.
  - MODE: `mode_reg` 반전(업/다운) → STOP.
- **검증 포인트**: RUN 중 Clear 무시가 의도인지(사양 확인 필요), 다운 카운트 0 도달 시 23:59:59.99로 랩어라운드.

### 4.6 `stopwatch_datapath` / `tick_counter` / `tick_gen_100hz`
- `tick_gen_100hz`: `run_stop=1`일 때만 0~999,999를 세고 1클럭 tick. `run_stop=0`이면 카운터 **유지**, tick은 0으로 강제(정지 후 tick이 1로 남는 문제 해결 주석 있음). clear 시 카운터 0.
- `tick_counter`: 입력 tick마다 ±1, TIMES-1(업)/0(다운) 경계에서 랩어라운드하며 다음 단 `o_tick` 1클럭. 4단 직렬 연결(msec→sec→min→hour), 리플 캐리 방식이라 상위 자리 갱신이 하위보다 단당 1클럭씩 늦다(10 ns 단위, 표시에는 무의미).
- 사실: `msec` 필드는 이름과 달리 **10 ms 단위(0~99, 센티초)**다. UART 출력에서는 `CC`로 표기.
- 사실: `if (rst | clear)`가 `posedge rst` 감지 블록 안에 있다 → §8-J.

### 4.7 `lap_time`
- `btn_lap` 펄스 시 4개 필드를 **동시에** 저장, `lap_valid=1`. 스톱워치 카운트는 계속 진행.
- 표시: `lap_valid && SW3`이면 랩 값, 아니면 현재 값. clear/리셋 시 랩 삭제.
- 랩은 1개만 저장(덮어쓰기). UART 상태 출력은 **랩이 아니라 현재 값**을 보낸다(`w_stopwatch_status`는 lap 이전 신호에서 구성).

### 4.8 `watch_control_unit` / `watch_setting_fsm`
- `watch_select = ~sw0 = is_watch`.
- `setting_request = 시계 모드 && SW5`.
- 상태: `NORMAL → (SW4=1이면 SET_min, 0이면 SET_msec)`로 진입.
- 이동: Right = 오른쪽(하위) 필드, Left = 왼쪽(상위) 필드, 순환.
  - Right: msec→hour→min→sec→msec (msec에서 Right는 hour로 순환)
  - Left: msec→sec→min→hour→msec
- `edit_enable = setting_request && 상태 != NORMAL`, `count_enable = ~setting_request` → **설정 중에는 시계가 멈춘다**(설정 시간만큼 실제 시간과 차이 발생, 의도된 설계 "Proposed: pause").
- `inc_pulse/dec_pulse`: 우선순위 Right > Left > Up > Down.
- `fnd_display_mode`: 설정 중에는 편집 필드에 맞게 자동 전환(hour/min 편집 → HH.MM 화면), 평상시에는 SW4.
- **검증 포인트**: SW5를 내리면 즉시 NORMAL, 설정 중 SW4 변경의 효과(진입 후에는 무시됨), 모드 전환 중 SW5가 켜져 있는 경우.

### 4.9 `watch_datapath_sw2` / `watch_editable_counter`
- 교수님 제공 `tick_counter`를 수정하지 않고 시계 전용 카운터를 별도 작성(주석에 명시).
- 우선순위: 수동 inc > 수동 dec > 자동 tick. 수동 편집은 **해당 필드만 랩어라운드, 다음 자리로 캐리/보로 없음**.
- `o_tick`을 매 클럭 0으로 먼저 대입 → 정지/편집 후 이전 캐리 펄스가 남지 않음.
- hour 리셋값 12 → 리셋 후 12:00:00.00.

### 4.10 `fnd_controller_stopwatch_watch`
- `clk_div_1600hz`(반주기 31,250클럭, 토글 출력)를 **클럭으로 쓰는** `counter_8`가 0~7 순환 → 슬롯 1개 = 625 µs, 8슬롯 = 5 ms.
- `decoder_2x4`는 `ds_sel[1:0]`만 사용 → 슬롯 k와 k+4가 같은 자리.
  - 슬롯 0~3: 숫자 4자리 (오른쪽부터 1의 자리)
  - 슬롯 4, 5, 7: `4'hF` = 꺼짐
  - 슬롯 6: AN2 자리에 `{3'b111, dot_onoff}` → msec < 50이면 `4'hE`(점만 켬), ≥ 50이면 꺼짐 → **0.5 s 주기 점 점멸**(가운데 구분점)
- 화면: SW4=0 → [sec10][sec1].[cs10][cs1], SW4=1 → [hour10][hour1].[min10][min1]. dp는 AN2의 점(왼쪽 쌍과 오른쪽 쌍 사이).
- 설계 이유(수업 노트): 4:1 MUX를 8:1로 확장해 점 전용 슬롯을 추가, 프레임 주파수가 반으로 줄어드는 것을 보상하려고 주파수를 2배(800→1600 Hz)로 올림.
- 결과: 각 숫자 자리는 5 ms 중 625 µs(1/8)만 켜짐. 리프레시 200 Hz.
- 점 점멸 기준은 SW4=1(HH.MM) 화면에서도 `msec`를 쓴다.

### 4.11 `watch_fnd_blink`
- FND 컨트롤러 **뒤에** 붙는 오버레이 (공용 FND 컨트롤러 수정 없이 기능 추가).
- 설정 중 0.5 s 간격으로 선택된 2자리의 숫자 세그먼트 `font[6:0]`만 끔. dp(`font[7]`)와 COM은 그대로 통과.
- 자리 매핑: `edit_field[0]=1`(sec, hour) → 왼쪽 쌍(AN3/AN2), 0(msec, min) → 오른쪽 쌍(AN1/AN0). 화면 모드 자동 전환(§4.8)과 결합해야 맞는 자리가 깜빡인다.
- 설정 진입 시 항상 "보이는 상태"에서 시작.

### 4.12 `sr04_top` / `SR04_sensor` / `baud_tick_gen_sr04`
- `baud_tick_gen_sr04`: `enable=1`일 때만 100클럭마다 1 µs tick, `clear` 또는 `enable=0`이면 카운터 0 → **측정 시작 시 tick 위상을 0부터 맞춤**.
- FSM (모든 카운트는 1 µs tick 기준)

| 상태 | 출력 | 동작 | 전이 |
|---|---|---|---|
| IDLE | clear=1 | 카운터 0 | `start_accept` → START |
| START | trigger=1, enable=1 | tick 카운트 | 카운트 11에서 다음 tick → WAIT (trigger ≈ 12 µs) |
| WAIT | enable=1 | echo 대기 | echo_sync=1 → DISTANCE / 36,000 µs → IDLE, distance=0 |
| DISTANCE | enable=1 | 58 µs마다 cm +1 | echo_sync=0 → distance 저장, STOP / 36,000 µs → IDLE, distance=0 |
| STOP | enable=1 | 약 10 ms 대기 | 10,000 카운트 후 IDLE |

- `start_accept = IDLE && start && !echo_sync && period_ready` : 측정 중 재요청 무시, 60 ms 이내 재요청 무시, echo가 High로 붙어 있으면 거부.
- 60 ms 주기 타이머는 100 MHz 클럭 카운터(6,000,000클럭)로 동작하며 `start_accept` 시점부터 센다. 주석에는 "6ms"라고 되어 있으나 실제는 60 ms.
- 거리 카운트: DISTANCE 진입 시 `echo_rem=1`로 시작(echo 상승 후 1 µs 지나서 상태가 바뀌는 것을 보정한 것이라고 주석에 명시).
- echo 2-FF 동기화.
- 측정 결과는 다음 성공/타임아웃까지 유지(IDLE에서 지우지 않음, `data_next=0` 주석 처리).
- **기존 시뮬레이션 결과**: §6.

### 4.13 `baud_tick_gen_dht11` / `dht11_controller`
- 1 µs tick은 항상 enable(측정 시작과 위상 맞춤 없음, 최대 1 µs 오차).
- 3-state: `assign dht11_io = control ? dht11_io_reg : 1'bz`. 실제로 구동하는 값은 START 상태의 0뿐 → **Low / High-Z만 출력**.
- 입력: 2-FF 동기화(`ASYNC_REG`) + 1클럭 지연 → `dht_rise`, `dht_fall` 엣지 검출. 리셋값 1(풀업 상태 가정).
- FSM

| 상태 | 동작 | 다음 |
|---|---|---|
| IDLE | 버스 해제 | `start && period_cnt==0 && 버스 High` → START (데이터/플래그 초기화) |
| START | 19,000 µs Low 구동 | 해제 → WAIT |
| WAIT | 센서 응답 Low 대기 | fall → SYNC_L |
| SYNC_L | 80 µs Low 구간 | rise → SYNC_H |
| SYNC_H | 80 µs High 구간 | fall → DATA_SYNC |
| DATA_SYNC | 비트 앞 50 µs Low | rise → DATA_BIT |
| DATA_BIT | High 유지 시간 측정 | fall: `tick ≥ 40` → 1, 아니면 0을 LSB로 시프트. 40비트면 STOP, 아니면 DATA_SYNC |
| STOP | 마지막 50 µs Low 후 | rise: 체크섬 OK → 습도/온도 갱신, valid=1 / 실패 → error=1 |

- WAIT~STOP 모든 상태에 **150 µs 타임아웃** → error=1, IDLE. FSM이 어떤 상황에서도 멈추지 않게 하는 장치.
- 최소 주기 카운터: µs 단위 다운카운트, 리셋 시에도 1,000,000 로드 → **리셋 후 1 s 동안 start 무시**(센서 전원 안정 시간).
- 실패 시 이전 습도/온도 레지스터 값은 유지되지만 `valid=0`이므로 화면에는 표시되지 않음.
- 수업 노트의 상태 설계(IDLE, START, WAIT, SYNCL, SYNCH, DATASYNC, DATA_BIT, BITDECISION, STOP)에서 BITDECISION을 DATA_BIT의 하강 엣지 처리로 합쳐 8상태로 구현. 노트 메모: "data_bit에서 0이 계속 출력되면 상태 전이가 안 됨 → DATA_SYNC, DATA_BIT 모두 상한(타임아웃) 추가".

### 4.14 `sensor_fnd_controller`
- 자체 스캔 카운터: 25,000클럭(250 µs)/자리, 4자리 1 ms(1 kHz). 시간 FND와 독립.
- 표시: AN3=접두 문자, AN2~AN0=백/십/일의 자리(앞자리 0도 표시).
  - SR04: `d` + 거리
  - DHT11: error → `Err `(AN3=E, AN2=r, AN1=r, AN0=공백), valid=0 → `----`, 정상 → `H`+습도 또는 `t`+온도
- 세그먼트 코드: d=`A1`, H=`89`, t=`87`, -=`BF`, r=`AF`, E=`86`.

### 4.15 `uart_fifo_loopback` (이름은 loopback이지만 실제로는 루프백 아님)
- 수업에서 만든 RX→FIFO→TX 루프백 구조를 바꿔, RX FIFO 출력은 decoder로, TX FIFO 입력은 sender에서 받는다.
- 출력 `rx_empty`는 실제로 **`~empty`(데이터 있음)** 신호다. 탑에서는 `w_uart_rx_not_empty`로 받아 의미를 바로잡아 사용.
- TX 시작: `tx_start = !tx_fifo_empty && !tx_busy && !tx_start_hold`.
  - `tx_start`가 곧 TX FIFO의 `pop`. `uart_tx`는 IDLE에서 `tx_data`(FIFO 조합 출력)를 같은 엣지에 래치.
  - `uart_tx`의 `tx_busy`는 tx_start 후 2번째 엣지에야 1이 되므로, 그 사이 1클럭 동안 다시 pop하지 않도록 `tx_start_hold_reg`를 둠.
- `baud_tick_gen`: 651클럭마다 tick (실제 baud = 100e6/651/16 ≈ 9600.6 bps, 오차 약 +0.006%).

### 4.16 `uart_tx`
- 상태 IDLE/START/DATA/STOP, 각 비트 16 tick. DATA에서 `data_reg[0]` 출력 후 오른쪽 시프트(LSB first, 시프트 레지스터 방식 = 수업 노트 "bit_count 인덱싱보다 와이어 절약").
- 비트 카운트 3비트(0~7). `tx_reg`로 출력 등록(글리치 방지).
- 사실: baud tick이 프리러닝이므로 Start 비트 첫 구간 길이는 최대 1 tick(1/16 비트)만큼 짧을 수 있다.

### 4.17 `uart_rx`
- IDLE: tick마다 rx 확인, 0이면 START.
- START: 8 tick째(인덱스 7) → Start 중앙 → DATA.
- DATA: 16 tick마다 rx를 MSB에 넣고 오른쪽 시프트(LSB first 복원), 8비트 후 STOP.
- STOP: 16 tick 후 `rx_done` 1클럭 → IDLE.
- 사실: Start 중앙에서 rx가 다시 0인지 재확인하지 않음, Stop 비트 값(1) 확인 없음, rx 입력 2-FF 동기화 없음. → §8-B.
- 사실: `localparam [2:0]`이지만 상태 레지스터는 `[1:0]` (값 0~3이라 동작 영향 없음).

### 4.18 `fifo` (`register_file` + `fifo_control_unit`)
- 쓰기: `we = ~full & push`, 동기 쓰기. 읽기: `rdata = mem[rptr]` 조합(비동기) 읽기 → pop과 같은 클럭에 데이터 사용 가능(First-Word-Fall-Through 형태).
- 제어: §2.7 규칙 그대로.
- 사실: `2'b00` 분기 안의 `if (rst)`는 조합 로직 안의 리셋 검사라 실질적으로 의미 없음(죽은 코드).
- 사실: full 상태에서 push+pop 동시 입력 → pop만 처리, 새 데이터는 **버려짐**(we=0). 그 순간 공간이 생기는데도 쓰지 않는 보수적 정책.
- full 상태에서 push 단독 → 무시(오버플로 플래그 없음).

### 4.19 `ascii_decoder`
- `enable` 클럭에 `pop=1`(조합) + 해당 바이트를 보고 다음 클럭에 명령 펄스(1클럭) 레지스터 출력.
- 인식 문자: R/r, C/c, U/u, S/s, 1~4. 그 외 문자는 pop만 되고 무시.
- `bin` 출력(0~F 16진 변환)은 이전 단계(UART+ASCII+FND) 기능의 흔적이며 탑에서 사용하지 않음.

### 4.20 `ascii_sender`
- 상태: IDLE / CONVERT / SEND. `ready = (state == IDLE)`.
- IDLE 우선순위: **에코 명령(r, c, u, 모드선택) > 상태 요청(s 또는 주기)**.
  - 상태 요청 시 그 순간의 `sw_mode`, `status_data`를 저장(스냅샷) → 변환 중 값이 바뀌어도 일관된 출력.
- CONVERT: 9비트 Double Dabble, 9클럭/값.
  - 시간 모드: hour → min → sec → cs 4회 변환(약 36클럭)
  - SR04: 1회, DHT11: 습도 정수 → 온도 정수 2회
- SEND: `idx`별 문자를 조합 로직으로 생성, `!full`일 때만 push하고 idx+1. 앞자리 0은 `skip_digit`로 push 없이 idx만 증가.
- 사실: 시간 상태 접두는 `0:`(스톱워치)/`1:`(시계)로 모드 코드 값이며, 모드 전환 명령 키(`1`=스톱워치, `2`=시계)와 숫자가 다르다.
- 사실: `s` 명령은 에코하지 않는다(상태 문자열로 응답).

---

## 5. 핵심 파라미터 계산표 (검증 시 기준값)

| 신호/모듈 | 파라미터 | 계산 | 결과 |
|---|---|---|---|
| tick_gen_100hz | F_COUNTER = 1,000,000 | 1e6 × 10 ns | 10 ms |
| baud_tick_gen | F_COUNT = 651 | 651 × 10 ns | 6.51 µs (16 tick = 104.16 µs = 1비트) |
| baud_tick_gen_sr04/dht11 | F_COUNT = 100 | 100 × 10 ns | 1 µs |
| btn_debounce | F_COUNT = 1000 | 샘플 10 µs × 8 | 약 80 µs |
| reset_input_filter | 1,000,000 | | 10 ms |
| reset_controller POR | 16 클럭 | | 160 ns |
| clk_div_1600hz | HALF = 31,250 | 62,500클럭 주기 | 1600 Hz, 슬롯 625 µs |
| sensor FND 스캔 | 25,000 | | 250 µs/자리, 1 kHz |
| 주기 상태 요청 | 49,999,999 | | 0.5 s |
| watch_fnd_blink | 50,000,000 | | 0.5 s on / 0.5 s off |
| SR04 trigger | 카운트 0~11 | | ≈ 12 µs (TB 측정 12.01 µs) |
| SR04 타임아웃 | 36,000 µs | | 36 ms |
| SR04 STOP | 0~10,000 | | ≈ 10 ms |
| SR04 최소 주기 | 60,000 × 100 | 6,000,000 클럭 | 60 ms |
| SR04 9비트 한계 | 511 cm × 58 | | echo ≈ 29.6~29.7 ms 초과 시 랩 |
| DHT11 START | 19,000 µs | | 19 ms (데이터시트 ≥ 18 ms) |
| DHT11 비트 판정 | ≥ 40 µs → 1 | | 0 ≈ 26~28 µs, 1 ≈ 70 µs |
| DHT11 타임아웃 | 150 µs/단계 | | |
| DHT11 최소 주기 | 1,000,000 µs | | 1 s |

---

## 6. 기존 검증 결과 (확인된 것)

### 6.1 `tb_sr04_top` (유일한 테스트벤치)
- 조건: 실제 보드 파라미터 그대로(100 MHz, 60 ms, 36 ms), 센서 모델 task(trigger 하강 200 µs 후 echo를 `거리×58 µs` 동안 High), `check()` task로 자동 PASS/FAIL 판정.
- 결과: **PASS 14 / FAIL 0** (설계자 보고, xsim, 시뮬레이션 약 585 ms)

| TC | 시나리오 | 기대 |
|---|---|---|
| TC1 | 리셋 직후 | IDLE, distance 0, trigger 0 |
| TC2 | echo 580 µs | 10 cm, trigger ≥ 10 µs |
| TC3 | 5,800 µs / 23,142 µs | 100 cm / 399 cm |
| TC4 | DISTANCE 중 start 재입력 | 무시, 30 cm |
| TC5 | 60 ms 이내 start | 거부 |
| TC6 | echo 무응답 | 36 ms 후 IDLE, 0 |
| TC7 | echo 38 ms | DISTANCE 타임아웃, 0 |
| TC8 | echo High 고정 | start 거부 |

### 6.2 검증이 아직 없는 범위 `[미확인]`
- 테스트벤치 없음: `uart_rx/tx`, `fifo`, `ascii_decoder`, `ascii_sender`, `dht11_controller`, 스톱워치/시계, `reset_controller`, `integrated_system_top` 전체.
- 노션 노트 기준으로 UART TX/RX·루프백·FIFO는 수업 중 개별 시뮬레이션을 했으나, **현재 프로젝트에 포함된 수정 버전**의 결과 자료는 없다.
- 보드 실측(ILA, 로직 분석기) 결과 자료 없음. 노션에는 ILA 사용법만 정리돼 있음.

---

## 7. 설계 히스토리 (설계 의도 파악용)

1. 게이트 → 가산기 → BCD/클럭분주 → 카운터 → FSM(Moore/Mealy) → 버튼 카운터(디바운스)
2. 미니 프로젝트: 스톱워치(교수님 기본 코드: datapath, tick_gen, tick_counter, fnd_controller, control_unit, btn_debounce) → 가운데 점 점멸, 랩타임, 시계 + SW2 시간 설정(이후 SW5로 재배치), LED 인디케이터
3. UART TX(ASM 설계, 데이터 레지스터 + 시프트) → RX(16× 오버샘플) → TX+RX 루프백 → UART + ASCII 디코더 + FND
4. 메모리/FIFO(동기식) → UART 루프백 + FIFO
5. 팀 프로젝트 ASCII sender: v1 루프백에서 신호 추출 → v2 ASCII로 tick 생성 → v3 sender
6. SR04 v1(echo_cal, tick_gen_us, trig_control 분리) → SR04 MASTER(FSM 통합, echo 동기화, `/58` 나눗셈 대신 카운터, 시뮬레이션용 센서 task)
7. DHT11(8상태, 단계별 타임아웃, 최소 주기)
8. 통합: `integrated_system_top`, 모드 3비트화, UART 원격 모드 선택, 선택 리셋 컨트롤러, 센서 FND 컨트롤러, 0.5 s 주기 상태 전송

수업에서 강조한 원칙(노션): "구현 목표 → 목표에 맞는 구조 설계", "제약조건을 설정하고 설계", "통신은 프로토콜과 보드 스펙 확인", "본인 코드·개념은 확실히(오답 금지)".

---

## 8. 검토가 필요한 지점 (설계자가 확인한 것이 아님 — 검증 AI가 판정할 것)

아래는 코드를 읽고 뽑은 **후보**다. 각 항목에 대해 실제 문제인지, 영향 범위, 재현 방법, 수정 필요 여부를 판정하라.

| ID | 위치 | 관찰된 사실 | 판정할 질문 |
|---|---|---|---|
| A | `btn_debounce`, `fnd_controller`(`counter_8`) | 로직으로 만든 펄스/토글 신호(`clk_1mhz`, `o_clk_1600hz`)를 다른 always 블록의 **클럭**으로 사용 | 클럭 제약 없는 생성 클럭 → 타이밍 분석 누락, 스큐 문제가 있는가? clock enable 방식이 맞는가? |
| B | `uart_rx` | rx 2-FF 동기화 없음, Start 중앙 재확인 없음, Stop 비트 검사 없음 | 노이즈 글리치가 가짜 바이트를 만드는가? 메타스테이블 위험 정도는? |
| C | `fifo` | full에서 push+pop 시 쓰기 버림, 오버플로 표시 없음 | RX FIFO(16)가 sender가 DHT11 문자열(약 35 ms)을 보내는 동안 넘칠 수 있는가? (9600 bps면 최대 약 1바이트/ms 수신) |
| D | `SR04_sensor` | 9비트 distance, DISTANCE 타임아웃은 36 ms(≈ 620 cm 해당) | echo가 29.7~36 ms일 때 값이 랩어라운드되어 작은 거리로 잘못 표시되는가? (설계자는 "센서 범위 밖이라 실사용 무관"으로 판단) |
| E | `SR04_sensor` 주석 | "6ms" 주석 vs 실제 60 ms | 문서/발표 자료와 불일치 여부 |
| F | `dht11_controller` / XDC | 풀업 필요, XDC 미등록 | 외부/내부 풀업 없이는 WAIT에서 rise/fall이 안 생겨 항상 error가 되는가? |
| G | `reset_controller` | 리셋 레지스터를 negedge clk에서 갱신 | posedge→negedge 반주기(5 ns) 경로가 생기는가? recovery/removal 여유는? |
| H | `integrated_system_top` | `active_mode_reg`, 필터 레지스터의 초기값을 선언부 초기화로 설정 | FPGA에서는 유효하지만 ASIC 이식성이 없음 — 이 프로젝트 목표에서 문제인가? |
| I | `ascii_sender` | 시간 상태 접두 `0:`/`1:` vs 모드 키 `1`/`2` | 사용자 혼동 가능성(기능 버그는 아님) |
| J | `tick_counter`, `tick_gen_100hz` | `always @(posedge clk, posedge rst)` 안에서 `if (rst \| clear)` | 비동기 리셋과 동기 clear가 한 조건식에 섞일 때 합성 결과(경고, 비동기 경로에 clear 포함 여부) |
| K | `control_unit` | RUN 상태에서 clear, mode 입력 무시 | 사양상 의도인지 확인 |
| L | `watch_setting_fsm` | 설정 중 시계 정지 | 설정을 끝낸 뒤 실제 시간과 어긋나는 것이 사양상 허용인가 |
| M | 주기 상태 전송 | 조건 미충족 시 그 회차 스킵, 재시도 없음 | UART 로그 시간 간격이 불규칙해지는 조건 |
| N | `uart_fifo_loopback` | 포트 이름 `rx_empty`가 실제로는 not-empty | 가독성/유지보수 문제 |
| O | 버튼 입력 | btnR/L/U/D는 `btn_debounce`의 시프트 레지스터 앞에 별도 동기화 없음 | 시프트 레지스터 첫 단이 동기화기 역할을 하는가? (A 항목과 연관) |

---

## 9. 검증 요청 방식과 출력 형식

### 9.1 검증 관점 (수업 「모델링 및 검증」 기준)
1. **Pass/Fail 판단**: 사양(이 문서 §1, §5)과 실제 동작 비교
2. **Characteristic**: 타이밍·주기·폭이 계산값과 일치하는가
3. **Checklist matching**: 시나리오 체크리스트를 빠짐없이 통과하는가
4. **Optimization**: 불필요한 로직, 중복, 개선 여지
5. **Intentional malfunction**: 의도적 오류 주입(센서 무응답, 체크섬 오류, 버튼 채터링, UART 프레이밍 오류, FIFO 넘침) 시 FSM이 멈추지 않고 복구되는가

불량 분석은 **문제 인식 → 원인 분석 → 해결 방안 → 적용 결과** 순서로 쓴다.

### 9.2 출력 형식 (반드시 이 형식)

```
## 검증 대상: <모듈/기능명>
### 1. 요약 판정: PASS / FAIL / 조건부 PASS / 판단 불가
### 2. 체크리스트
| No | 항목 | 기대값(근거) | 관찰값(근거) | 판정 |
### 3. 발견 사항
- [등급: 버그/의심/개선] <제목>
  - 근거: 파일명, 신호명, 조건
  - 재현 시나리오: 입력/상태 → 잘못된 출력
  - 영향: 기능/타이밍/보드 동작
  - 수정 제안: 구체적인 코드 수준 변경
### 4. 확인 불가 항목과 필요한 추가 자료
### 5. 추가로 돌려볼 시뮬레이션 시나리오
```

### 9.3 이 프로젝트에 대해 우선 요청할 검증 (예시 질문)
1. §8 표 A~O 각각에 대한 판정
2. `uart_rx` + `fifo` + `ascii_decoder` + `ascii_sender` 경로의 테스트벤치 시나리오 설계 (연속 입력, sender busy 중 입력, 알 수 없는 문자, 프레이밍 오류)
3. `dht11_controller` 테스트벤치 시나리오 설계 (정상, 체크섬 오류, 각 단계 무응답, 1 s 이내 재요청, 리셋 직후 요청)
4. 모드 전환 + 리셋 조합 시나리오 (UART 모드 전환 후 스위치 조작, BTNC 선택 리셋, SW15 유지)
5. 발표용 "시뮬레이션 파형 → 목표, 시나리오, 결과" 구성이 맞는지, 결과와 고찰이 구분되어 있는지 검토

---

## 10. 용어 정리 (이 프로젝트 기준)

| 용어 | 의미 |
|---|---|
| tick | 100 MHz 1클럭 폭 enable 펄스 |
| b_tick | baud tick (UART: 비트시간/16, 센서: 1 µs) |
| msec / cs | 이 프로젝트의 `msec`는 10 ms 단위(센티초). UART에서는 CC |
| 선택 리셋 | BTNC: 현재 시간 모드만 리셋 |
| 전역 리셋 | POR 또는 SW15 |
| FND | 4자리 7-세그먼트, Active Low |
| sender / decoder | `ascii_sender` / `ascii_decoder` |
| valid / error | DHT11 측정 성공 / 실패(타임아웃 또는 체크섬) |
