#!/bin/bash
# 회원가입 → 방 만들기 → 지도 확인 → 다른 계정 입장 — 2 시뮬 UI 자동화.
#
# 흐름:
#   1) A/B 두 계정 API 가입 + SSH 폰인증 우회 + 프로필 + 자녀 등록
#      (KCP 본인인증은 WebView 라 UI 자동화 불가 — 기존 e2e 와 동일하게 우회)
#   2) 방은 미리 만들지 않음 — Sim A 가 UI 로 직접 생성
#   3) test_results 초기화
#   4) Sim A drive — 회원가입 폼 시연 + A 로그인 + 방 만들기(UI) + 지도 확인
#   5) Sim B drive — B 로그인 + A 가 만든 방 입장 + 채팅
#
# A 가 UI 로 방을 만든 뒤 B 가 같은 제목(ROOM_TITLE)으로 카드를 찾아 입장하므로
# 시뮬을 순차 실행한다 (A 완료 후 B 시작).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
SIM_A="${SIM_A:-1CCE8E44-C182-4137-8E1A-CB67CBD1CC0B}"   # kids
SIM_B="${SIM_B:-973A77C8-1724-4105-8197-7E1B60CEA4AF}"   # iPhone 17
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results}"

for bin in curl jq flutter ssh python3; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 없음"; exit 1; }
done

TS=$(date +%s)
EMAIL_A="signup_a_${TS}@test.com"
EMAIL_B="signup_b_${TS}@test.com"
NICK_SUFFIX="${TS: -6}"
ROOM_TITLE="가입방만들기_${NICK_SUFFIX}"

echo "=============================="
echo "  회원가입→방만들기→지도→입장 UI e2e"
echo "  API : $API_URL"
echo "  SimA: $SIM_A  ($EMAIL_A)"
echo "  SimB: $SIM_B  ($EMAIL_B)"
echo "  Room: $ROOM_TITLE  (A 가 UI 로 생성)"
echo "=============================="

ssh_psql() {
  local sql="$1"
  local b64
  b64=$(printf '%s' "$sql" | base64 | tr -d '\n')
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_HOST" bash <<EOF
set -a
source ~/kids-server/.env.production 2>/dev/null || source ~/kids-server/.env
set +a
DECODED=\$(echo "$b64" | base64 -d)
psql "postgresql://\$DB_USER:\$DB_PASSWORD@\$DB_HOST:\${DB_PORT:-5432}/\$DB_NAME" \
  -v ON_ERROR_STOP=1 -c "\$DECODED"
EOF
}

register() {
  curl -fsS -X POST "$API_URL/auth/email/register" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$PASSWORD\"}"
}

extract() {
  echo "$1" | jq -r ".data.$2 // .$2 // empty"
}

auth_post() {
  curl -fsS -X POST "$API_URL$2" \
    -H "Authorization: Bearer $1" -H 'Content-Type: application/json' -d "$3"
}

setup_account() {
  # $1 token  $2 nickPrefix
  auth_post "$1" "/users/profile" "{
    \"nickname\":\"$2${NICK_SUFFIX}\",
    \"parentGender\":\"MOM\",
    \"isSingleParent\":false,
    \"regionSido\":\"서울특별시\",
    \"regionSigungu\":\"강남구\",
    \"regionDong\":\"역삼동\"
  }" >/dev/null
  # 0~36개월 기본 범위 안에 들어가도록 자녀 개월수를 맞춘다.
  auth_post "$1" "/children" \
    '{"nickname":"아이","birthYear":2023,"birthMonth":11,"gender":"FEMALE"}' \
    >/dev/null
}

echo ""
echo ">>> [1/4] A 가입 + 셋업..."
A_RAW=$(register "$EMAIL_A")
A_TOKEN=$(extract "$A_RAW" 'accessToken')
A_ID=$(extract "$A_RAW" 'user.id')
[ -z "$A_TOKEN" ] && { echo "❌ A 가입 실패: $A_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$A_ID';"
setup_account "$A_TOKEN" "sa"

echo ""
echo ">>> [2/4] B 가입 + 셋업..."
B_RAW=$(register "$EMAIL_B")
B_TOKEN=$(extract "$B_RAW" 'accessToken')
B_ID=$(extract "$B_RAW" 'user.id')
[ -z "$B_TOKEN" ] && { echo "❌ B 가입 실패: $B_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$B_ID';"
setup_account "$B_TOKEN" "sb"

echo ""
echo ">>> [3/4] $RESULTS_DIR 초기화..."
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# ─── 스크린샷 HTTP 서버 (9998) ───────────────────────────────
# integration_test 의 Flutter surface 캡처(convertFlutterSurfaceToImage)가
# iOS 26.4 시뮬에서 멈춘다. match 프로젝트처럼 시뮬 안의 _shot 이 이 서버로
# HTTP 요청을 보내면 호스트가 `simctl io screenshot` 으로 네이티브 캡처한다.
# 요청 경로의 prefix(A_/B_)로 어느 시뮬을 캡처할지 고른다.
echo ">>> 스크린샷 HTTP 서버 기동 (127.0.0.1:9998)..."
SCREENSHOT_DIR="$RESULTS_DIR" UDID_A="$SIM_A" UDID_B="$SIM_B" python3 -u -c '
import http.server, socketserver, subprocess, os
UDIDS = {"A": os.environ["UDID_A"], "B": os.environ["UDID_B"]}
DIR = os.environ["SCREENSHOT_DIR"]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers()
        name = self.path.strip("/").split("?")[0]
        role = name.split("_")[0] if name else ""
        udid = UDIDS.get(role, "")
        if udid and name:
            subprocess.run(["xcrun","simctl","io",udid,"screenshot",os.path.join(DIR, f"{name}.png")], check=False, timeout=5)
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", 9998), H) as s: s.serve_forever()
' &
SHOT_PID=$!
trap "kill $SHOT_PID 2>/dev/null || true" EXIT
sleep 1

drive_role() {
  local role="$1" sim="$2" email="$3"
  # 이전 테스트 세션이 iOS Keychain 에 남으면 자동 로그인 race 가 생긴다
  # (uninstall 로는 Keychain 이 안 지워짐). erase 로 시뮬을 공장 초기화해
  # Keychain 까지 비운 뒤 부팅한다. .app 캐시도 함께 무효화된다.
  xcrun simctl shutdown "$sim" >/dev/null 2>&1 || true
  xcrun simctl erase "$sim" >/dev/null 2>&1 || true
  xcrun simctl boot "$sim" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$sim" >/dev/null 2>&1 || true
  # 시뮬 위치 설정(강남구 중심) — 폴백 좌표가 같은 강남구 일대라 핀이 화면에.
  xcrun simctl location "$sim" set 37.5172,127.0473 >/dev/null 2>&1 || true
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$sim" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/ui_signup_create_map_test.dart \
    --dart-define=API_BASE_URL="${API_URL%/v1}" \
    --dart-define=ENVIRONMENT=production \
    --dart-define=UI_TEST_EMAIL="$email" \
    --dart-define=UI_TEST_PASSWORD="$PASSWORD" \
    --dart-define=UI_TEST_ROLE="$role" \
    --dart-define=UI_TARGET_ROOM_TITLE="$ROOM_TITLE" \
    --dart-define=UI_TEST_LAT=37.5172 \
    --dart-define=UI_TEST_LNG=127.0473 \
    --dart-define=BUILD_ID="signup-${TS}-${role}-${RANDOM}" 2>&1 | sed "s/^/[$role] /"
}

echo ""
echo ">>> [4/4] Sim A drive (회원가입 + 방 만들기 + 지도)..."
# drive 가 [E] 로 끝나도(렌더링 overflow 예외 등) 스크린샷은 남는다 —
# 다음 단계(B)를 막지 않도록 실패를 허용한다.
drive_role A "$SIM_A" "$EMAIL_A" || echo "  (A drive 비정상 종료 — test_results 스크린샷 확인)"

echo ""
echo ">>> Sim B drive (다른 계정 로그인 + 방 입장)..."
drive_role B "$SIM_B" "$EMAIL_B" || echo "  (B drive 비정상 종료 — test_results 스크린샷 확인)"

echo ""
echo "=============================="
echo "  완료. 스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" | sed 's/^/    /'
echo "  A: $EMAIL_A ($A_ID)"
echo "  B: $EMAIL_B ($B_ID)"
echo "  Room: $ROOM_TITLE  (A 가 UI 로 생성)"
echo "=============================="
