# Kids 앱 e2e 시나리오 (integration_test)

flutter `integration_test` 기반 e2e 테스트. **시뮬레이터 2대 병렬**로 A(방장)와 B(참여자) 시나리오를 동시에 돌리고, 각 단계마다 스크린샷을 **`test_results/` 단일 디렉토리에 평탄하게** PNG로 저장합니다.

## 디렉토리

```
app/
├── run_e2e.sh                          # orchestrator (회원가입+본인인증 우회+사전 setup+2-sim 병렬)
├── test_results/                       # 스크린샷 출력 (실행마다 비워짐)
├── test_driver/
│   └── integration_test.dart           # flutter drive 진입점 + onScreenshot 콜백
└── integration_test/
    ├── README.md                       # 본 문서
    ├── main_scenario_test.dart         # role(A/B) 분기 시나리오
    └── helpers/
        ├── test_config.dart            # 환경변수 상수 (role, tokens, roomId 등)
        └── api_helper.dart             # Dio 기반 서버 API 래퍼
```

## 시나리오 흐름

orchestrator 가 미리 처리:
1. A, B 두 계정을 API 로 회원가입
2. SSH+psql 로 `is_phone_verified=true` UPDATE (KCP 우회)
3. A 토큰으로 프로필 setup + 아이 등록 + **방 생성** → `roomId` 추출
4. B 토큰으로 프로필 setup + 아이 등록
5. `test_results/` 초기화

그 다음 두 시뮬에 **병렬 `flutter drive`** — 동일 시나리오에 `TEST_USER_ROLE=A` / `B` 만 다르게 주입:

**A (방장)**
- 부팅 → `A_00_boot.png`
- 홈 → `A_01_home.png`
- 채팅 메시지 전송 → `A_02_after_send_chat.png`
- 메시지 리스트 fetch (B 메시지 포함) → `A_03_messages_fetched.png`
- B 신고 → `A_04_after_report.png`

**B (참여자)**
- 부팅 → `B_00_boot.png`
- 홈 → `B_01_home.png`
- 방 참여(FREE join) → `B_02_after_join.png`
- 채팅 메시지 전송 → `B_03_after_send_chat.png`
- 메시지 리스트 fetch → `B_04_messages_fetched.png`

스크린샷은 모두 `app/test_results/` 한 곳에 평탄하게 쌓입니다.

## 전제 조건

- macOS + Xcode (iOS 시뮬레이터 2대)
- `flutter`, `curl`, `jq`, `ssh` 가 PATH 에 있어야 함
- 시뮬레이터 2대가 미리 부팅돼 있거나, `flutter drive` 가 띄울 수 있는 상태
- EC2 SSH 키 (`kids-key.pem`) 와 EC2 호스트 접근 권한

## 실행

```bash
cd app
./run_e2e.sh
```

환경변수로 override 가능:

| 변수 | 기본값 | 설명 |
|---|---|---|
| `TEST_API_BASE_URL` | `https://api.growtogether.kr/v1` | 테스트 대상 서버 |
| `KIDS_SSH_KEY` | `../kids-key.pem` | EC2 SSH 키 경로 |
| `KIDS_SSH_HOST` | `ubuntu@43.201.221.240` | EC2 호스트 |
| `SIM_DEVICE_A` | `iPhone 15` | 방장 시뮬레이터 이름/UDID |
| `SIM_DEVICE_B` | `iPhone 15 Pro` | 참여자 시뮬레이터 이름/UDID |
| `E2E_PASSWORD` | `Test1234!` | 테스트 계정 비밀번호 |
| `TEST_RESULTS_DIR` | `<app>/test_results` | 스크린샷 출력 디렉토리 |

`flutter devices` 로 시뮬레이터 이름/UDID 확인 후 `SIM_DEVICE_A/B` 를 지정하세요.

## 한계 / 주의

- **UI tap 최소화** — 각 화면 진입(첫 프레임) + API 호출 기반 행동 + 스크린샷 캡처. 위젯 Key 가 정리되면 UI tap 흐름을 단계적으로 추가 가능.
- **user-to-user 차단 미검증** — kids 서버에 endpoint 가 없어 빠짐. admin 측 e2e(`admin/tests/ban.spec.ts`) 에서 `PATCH /v1/admin/users/:id/ban` 으로 검증.
- **클린업** — orchestrator 가 자동 삭제하지 않음. `run_e2e.sh` 하단 주석의 SQL 을 필요 시 수동 실행. 운영 DB 에 더미가 쌓이지 않게 별도 e2e/stg 환경 권장.
- **스크린샷 충돌** — A 와 B 가 동시에 PNG 를 쓰지만 이름이 role prefix 로 분리되어 있어 같은 디렉토리에서도 충돌 없음.

## 주의

`TEST_API_BASE_URL` 이 운영 서버를 가리키면 실제 DB 에 더미 데이터(유저 2명, 방 1개, 채팅, 신고 1건)가 들어갑니다. 가능하면 별도 e2e/staging 환경에서 돌리세요.
