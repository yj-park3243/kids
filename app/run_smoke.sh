#!/bin/bash
# 앱 전 화면 스모크 테스트 — kids·iPhone17 두 디바이스에서 순차 실행.
#
# 흐름:
#   1) HOST 가입 + 셋업 + 방 1개 생성 (방 상세/카드 검증용)
#   2) USER 가입 + 셋업 (스모크 주체)
#   3) 스크린샷 HTTP 서버 기동
#   4) flutter drive — ui_smoke_test (kids → iPhone17)
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
# ─── 시뮬레이터 해석 ────────────────────────────────────────────────────
# 기본값/환경변수 UDID 가 이 머신에 없으면 flutter drive 가 디바이스를 못 찾고
# 그냥 끝난다. 실존하면 그대로 쓰고, 없을 때만 사용 가능한 iPhone 시뮬을
# 목록 순서대로 대신 고른다. SDKROOT 가 stale 하면 xcrun 이 simctl 조차 못
# 찾으므로 조회할 때만 벗긴다.
SIM_AVAILABLE="$( (unset SDKROOT; xcrun simctl list devices available) 2>/dev/null || true )"
SIM_NAMES="$(sed -nE 's/^[[:space:]]+(.*) \([0-9A-Fa-f-]{36}\) \(.*/\1/p' <<<"$SIM_AVAILABLE")"
SIM_IPHONES="$(sed -nE 's/^[[:space:]]+iPhone[^(]*\(([0-9A-Fa-f-]{36})\).*/\1/p' <<<"$SIM_AVAILABLE")"

sim_exists() {   # UDID 든 기기 이름이든 (flutter drive 는 둘 다 받는다)
  [ -n "${1:-}" ] || return 1
  if grep -qF "($1)" <<<"$SIM_AVAILABLE"; then return 0; fi
  grep -qxF "$1" <<<"$SIM_NAMES"
}

# resolve_sim <원하는값> <라벨> [이미_배정된_UDID...] — 없으면 대체 UDID 를 출력.
resolve_sim() {
  local want="${1:-}" label="$2"; shift 2
  local taken=" $* " udid
  if sim_exists "$want"; then printf '%s' "$want"; return 0; fi
  for udid in $SIM_IPHONES; do
    case "$taken" in *" $udid "*) continue ;; esac   # 2대 이상 쓸 때 중복 배정 방지
    echo "  ⚠️  $label: '$want' 가 이 머신에 없어 $udid 로 대체" >&2
    printf '%s' "$udid"; return 0
  done
  echo "❌ $label 로 쓸 iPhone 시뮬레이터가 없다 — 'xcrun simctl list devices available' 확인 후 $label 환경변수로 지정하라." >&2
  return 1
}

SIM_A="$(resolve_sim "${SIM_A:-447803FE-BD81-4025-A533-BB4099269D6E}" SIM_A)" || exit 1            # iPhone 17 Pro
SIM_B="$(resolve_sim "${SIM_B:-72277065-7CE6-4908-82AE-3C6DBE39FF4C}" SIM_B "$SIM_A")" || exit 1   # iPhone 17
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results}"

for bin in curl jq flutter ssh python3; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 없음"; exit 1; }
done

TS=$(date +%s)
HOST_EMAIL="smokehost_${TS}@test.com"
USER_EMAIL="smokeuser_${TS}@test.com"
NICK_SUFFIX="${TS: -6}"
# 방 날짜는 오늘 — 날짜 필터가 무엇이든 홈 목록에 보이도록.
TODAY=$(date +%Y-%m-%d)

echo "=============================="
echo "  앱 전 화면 스모크 — 2 디바이스"
echo "  API  : $API_URL"
echo "  kids : $SIM_A"
echo "  ip17 : $SIM_B"
echo "  USER : $USER_EMAIL"
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
  auth_post "$1" "/users/profile" "{
    \"nickname\":\"$2${NICK_SUFFIX}\",
    \"parentGender\":\"MOM\",
    \"isSingleParent\":false,
    \"regionSido\":\"서울특별시\",
    \"regionSigungu\":\"강남구\",
    \"regionDong\":\"역삼동\"
  }" >/dev/null
  auth_post "$1" "/children" \
    '{"nickname":"아이","birthYear":2023,"birthMonth":11,"gender":"FEMALE"}' \
    >/dev/null
}

echo ""
echo ">>> [1/4] HOST 가입 + 방 생성..."
HOST_RAW=$(register "$HOST_EMAIL")
HOST_TOKEN=$(extract "$HOST_RAW" 'accessToken')
HOST_ID=$(extract "$HOST_RAW" 'user.id')
[ -z "$HOST_TOKEN" ] && { echo "❌ HOST 가입 실패: $HOST_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$HOST_ID';"
setup_account "$HOST_TOKEN" "sh"
ROOM_RAW=$(auth_post "$HOST_TOKEN" "/rooms" "{
  \"title\":\"스모크방_${NICK_SUFFIX}\",
  \"description\":\"스모크 테스트용 자유입장 방\",
  \"placeType\":\"PLAYGROUND\",
  \"joinType\":\"FREE\",
  \"genderFilter\":\"ALL\",
  \"singleParentOnly\":false,
  \"ageMonthMin\":0,
  \"ageMonthMax\":84,
  \"maxMembers\":10,
  \"date\":\"$TODAY\",
  \"startTime\":\"14:00\",
  \"regionSido\":\"서울특별시\",
  \"regionSigungu\":\"강남구\",
  \"regionDong\":\"역삼동\",
  \"placeAddress\":\"서울 강남구 테헤란로 152\"
}")
ROOM_ID=$(extract "$ROOM_RAW" 'id')
echo "  room.id = $ROOM_ID"

echo ""
echo ">>> [2/4] USER 가입 + 셋업..."
USER_RAW=$(register "$USER_EMAIL")
USER_TOKEN=$(extract "$USER_RAW" 'accessToken')
USER_ID=$(extract "$USER_RAW" 'user.id')
[ -z "$USER_TOKEN" ] && { echo "❌ USER 가입 실패: $USER_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$USER_ID';"
setup_account "$USER_TOKEN" "su"

echo ""
echo ">>> [3/4] $RESULTS_DIR 초기화 + 스크린샷 서버..."
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"
SCREENSHOT_DIR="$RESULTS_DIR" SIM_A="$SIM_A" SIM_B="$SIM_B" python3 -u -c '
import http.server, socketserver, subprocess, os
UDIDS = {"kids": os.environ["SIM_A"], "ip17": os.environ["SIM_B"]}
DIR = os.environ["SCREENSHOT_DIR"]
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        self.send_response(200); self.end_headers()
        name = self.path.strip("/").split("?")[0]
        role = name.split("_")[0] if name else ""
        udid = UDIDS.get(role, "")
        if udid and name:
            subprocess.run(["xcrun","simctl","io",udid,"screenshot",os.path.join(DIR, f"{name}.png")], check=False, timeout=15)
    def log_message(self, *a): pass
socketserver.TCPServer.allow_reuse_address = True
with socketserver.TCPServer(("127.0.0.1", 9998), H) as s: s.serve_forever()
' &
SHOT_PID=$!
trap "kill $SHOT_PID 2>/dev/null || true" EXIT
sleep 1

run_on() {
  local tag="$1" sim="$2"
  echo ""
  echo ">>> [$tag] 스모크 drive — $sim"
  # 다른 시뮬을 모두 끄고 대상 시뮬만 부팅 — flutter drive 가 디바이스를
  # 혼동하지 않도록 (두 시뮬이 동시에 booted 면 두 번째 drive 가 빌드 후
  # 디바이스를 못 찾고 종료하는 현상이 있었다).
  xcrun simctl shutdown all >/dev/null 2>&1 || true
  xcrun simctl erase "$sim" >/dev/null 2>&1 || true
  xcrun simctl boot "$sim" >/dev/null 2>&1 || true
  xcrun simctl bootstatus "$sim" >/dev/null 2>&1 || true
  # erase 직후 시뮬 내부 서비스가 안정될 때까지 대기 — 바로 install 하면
  # 'Mach error -308 server died' 로 설치가 실패하는 경우가 있다.
  sleep 15
  xcrun simctl location "$sim" set 37.5172,127.0473 >/dev/null 2>&1 || true
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$sim" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/ui_smoke_test.dart \
    --dart-define=API_BASE_URL="${API_URL%/v1}" \
    --dart-define=ENVIRONMENT=production \
    --dart-define=UI_TEST_EMAIL="$USER_EMAIL" \
    --dart-define=UI_TEST_PASSWORD="$PASSWORD" \
    --dart-define=UI_TEST_LAT=37.5172 \
    --dart-define=UI_TEST_LNG=127.0473 \
    --dart-define=UI_DEVICE_TAG="$tag" \
    --dart-define=BUILD_ID="smoke-${TS}-${tag}-${RANDOM}" 2>&1 | sed "s/^/[$tag] /" \
    || echo "  ($tag drive 비정상 종료 — SMOKE_FAIL 로그 확인)"
}

echo ""
echo ">>> [4/4] flutter drive — 스모크 (kids → iPhone17)..."
run_on kids "$SIM_A"
run_on ip17 "$SIM_B"

echo ""
echo "=============================="
echo "  완료. 스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" | sed 's/^/    /'
echo "  USER: $USER_EMAIL ($USER_ID)"
echo "=============================="
