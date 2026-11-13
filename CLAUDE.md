# 26_AI_CAMP_2 — Verilog / Vivado 실습 (Basys-3)

## 폴더 지도
- 실습마다 Vivado 프로젝트 하나: `YYYYMMDD_주제/` (예: `20261015_uart/`)
- 소스는 그 안의 `.srcs/`에만 있음 — 이 경로만 읽을 것
  - RTL: `<프로젝트>.srcs/sources_1/{new,imports}/`
  - 테스트벤치: `<프로젝트>.srcs/sim_1/{new,imports}/`
  - 제약(XDC): `<프로젝트>.srcs/constrs_1/`
  - `imports/` 아래는 다른 날짜 프로젝트에서 복사해 온 파일일 수 있음
- 공통 핀 제약 원본: `Basys-3-Master.xdc` (루트)
- `counter/`: 프로젝트 없이 둔 .v 파일 모음
- 읽지 말 것: `.runs/ .cache/ .sim/ .hw/ .ip_user_files/ .Xil/`, `*.jou *.log *.dcp *.bit *.wdb *.zip` (자동 생성물, settings.json에서 차단됨)

## 읽기 습관
- 위치를 모르면 Grep/Glob으로 먼저 찾고, 해당 줄 범위만 읽기 (파일 전체 읽기 X)
- 사용자가 날짜/주제를 말하면 그 프로젝트 폴더 안에서만 탐색
- 합성·시뮬 로그가 필요하면 전체를 읽지 말고 Bash로 걸러서 보기:
  `grep -iE "error|critical warning" <로그> | head -50` 또는 `tail -50 <로그>`
- 수정 후 파일 전체를 다시 읽어 확인하지 말 것 — 바뀐 부분만 확인
- 여러 프로젝트를 훑는 탐색은 Explore 에이전트에 맡기고 결론만 받기
- 단, 모듈 간 포트/인스턴스 연결 버그는 관련 모듈(top + 하위)을 처음부터 같이 읽기
