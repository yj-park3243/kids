# Kids Admin e2e (Playwright)

Kids admin 의 실제 UI 동작을 검증하는 Playwright 테스트입니다. 신고 페이지 노출과 회원 차단 흐름을 커버합니다.

## 디렉토리

```
admin/
├── playwright.config.ts            # ADMIN_BASE_URL 환경변수로 로컬/운영 분기
├── tests/
│   ├── README.md                   # 본 문서
│   ├── smoke.spec.ts               # 기존 모킹 기반 스모크 (그대로 유지)
│   ├── reports.spec.ts             # 신고 페이지 e2e
│   ├── ban.spec.ts                 # 회원 차단 e2e
│   └── helpers/
│       ├── auth.ts                 # loginAsAdmin
│       ├── nav.ts                  # Ant 사이드바 clickMenu
│       └── db.ts                   # SSH+psql 유틸 (kids EC2 → RDS)
```

## 전제 조건

- Node 18+ + `npm install` 완료
- `ADMIN_PASSWORD` 환경변수 (admin 계정 비밀번호) — 필수
- 운영 admin 으로 돌릴 때: kids EC2 SSH 키 (`KIDS_SSH_KEY`, 기본 `~/WebProject2/kids/kids-key.pem`) 와 접근 권한
- `ssh`, `psql` 이 PATH 에 있어야 함 (db.ts 가 사용)

## 실행

로컬 dev 서버에 대해 (vite dev 가 자동 부팅됨):

```bash
ADMIN_PASSWORD='xxx' npm run test:e2e
```

운영 admin 에 대해:

```bash
ADMIN_BASE_URL='https://admin.growtogether.kr' \
ADMIN_PASSWORD='xxx' \
npm run test:e2e
```

특정 spec 만:

```bash
ADMIN_PASSWORD='xxx' npm run test:e2e -- -g '신고 row'
```

UI 모드:

```bash
ADMIN_PASSWORD='xxx' npm run test:e2e:ui
```

## 환경변수

| 변수 | 기본값 | 설명 |
|---|---|---|
| `ADMIN_BASE_URL` | `http://localhost:5174` | 테스트할 admin URL. 로컬이면 dev 서버 자동 부팅. |
| `ADMIN_USERNAME` | `dydwn3243@gmail.com` | admin 로그인 아이디 |
| `ADMIN_PASSWORD` | (없음) | admin 비밀번호 — 필수 |
| `KIDS_SSH_KEY` | `~/WebProject2/kids/kids-key.pem` | EC2 SSH 키 경로 |
| `KIDS_SSH_HOST` | `ubuntu@43.201.221.240` | EC2 호스트 |

## 시나리오 요약

### reports.spec.ts

1. SSH+psql 로 시드 유저 2명(reporter, target) + `user_report` row 1건 INSERT (detail 에 timestamp marker)
2. admin 로그인 → 사이드바 "신고 관리" 클릭 → /reports 로 이동
3. 테이블에 marker 가 있는 row 가 보이는지 + 사유/상태 라벨 확인
4. 시드 데이터 cleanup

### ban.spec.ts

1. SSH+psql 로 시드 유저 1명 (status=ACTIVE) INSERT
2. admin 로그인 → `/users/<id>` 직접 진입
3. "정지" 버튼 → Popconfirm "확인"
4. antd success message 확인 + DB 에서 `status='BANNED'` 검증
5. 시드 유저 cleanup

## 한계 / 주의

- **DB 시드 의존** — psql 로 직접 INSERT. user 테이블에 컬럼이 추가되면 시드 INSERT 도 손봐야 함.
- **운영 DB 오염 가능성** — `afterAll` 의 DELETE 가 실패하면 더미 row 가 남음. 테스트 실행 후 `e2e_*` 로 시작하는 마커 row 가 없는지 가끔 확인 권장. 가능하면 별도 e2e/staging 환경에서 돌릴 것.
- **`smoke.spec.ts` 는 그대로 유지** — 모킹 기반이라 DB/서버 의존이 없음. 독립적으로 동작.
- **순차 실행 강제** — `fullyParallel: false`, `workers: 1`. 시드 데이터 충돌 방지.
