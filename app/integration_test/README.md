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

> 참고: 위 A/B 요약은 초기 2-sim 버전 기준이며, 현재 코드는 **A/B/C 3-sim × 다중 라운드**입니다. 전체 케이스 매핑은 [`docs/08_테스트시나리오.md`](../../docs/08_테스트시나리오.md) 부록 A 참고.

### 확장 라운드 (Round 4~6)

기존 Round 1~3(방 생성/참여/승인/거부/채팅/후기) 위에 부작용 없는 자동화 케이스를 추가했습니다.

- **Round 4 — B**: A 팔로우(`POST /follows`) + 팔로잉 목록 확인, 위치 노출(참여 확정자는 `placeName` 공개)
- **Round 4 — C**: A 신고(`POST /reports`), 위치 노출(비참여자는 `placeName` 비공개), 비방장 출석 체크 거부(403)
- **Round 5 — A**: 출석 체크 제출(`POST /rooms/:id/attendance`), 후기 수정(`PATCH /reviews/:id`)
- **Round 6 — A**: 프로필 수정 불가 필드(parentGender/isSingleParent) 검증, 내 모임(예정/지난) 조회, 외부 프로필 한부모 비노출 확인

> **Round 2 승인 처리 버그 수정**: 기존 헬퍼가 신청 수락에 `{status:'APPROVED'}`를 보냈으나 서버 `JoinActionDto`는 `{action:'ACCEPT'}`를 기대하며, `forbidNonWhitelisted` 설정상 400으로 거부되고 있었습니다. 정식 페이로드로 수정해 Round 2가 실제로 통과하도록 했습니다.

> **차단(block) 양방향**은 서버가 차단 시 공유 방 멤버십을 삭제해(`removeSharedRoomMembership`) 3-user 공유방 셋업의 다른 역할과 충돌하므로 자동화에서 제외했습니다(격리 계정/방 셋업 시 가능). docs/08 BLK-* 참고.

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
