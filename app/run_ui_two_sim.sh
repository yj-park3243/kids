#!/bin/bash
# 2 시뮬 UI 자동화 — 방장(A) + 참여자(B) 양방향 채팅.
#
# 흐름:
#   1) A/B 두 계정 가입 + 폰인증 + 프로필 + 자녀
#   2) A 토큰으로 FREE 방 사전 생성 (UI 자동화에서 사용하기 어려운 날짜/지역은 API 로 채움)
#   3) test_results 초기화
#   4) Sim A 에서 drive (방 진입 + 채팅 송신) — 끝까지 wait
#   5) Sim B 에서 drive (입장 + A 메시지 확인 + 채팅 답장)
#
# 빌드 race 회피를 위해 시뮬을 순차 실행. A 가 끝난 후 B 가 진입해 A 의
# 메시지를 보고 답장하는 자연스러운 흐름.
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

for bin in curl jq flutter ssh; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 없음"; exit 1; }
done

TS=$(date +%s)
EMAIL_A="ui2a_${TS}@test.com"
EMAIL_B="ui2b_${TS}@test.com"
NICK_SUFFIX="${TS: -6}"
TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

echo "=============================="
echo "  2-sim UI e2e"
echo "  API: $API_URL"
echo "  SimA: $SIM_A  ($EMAIL_A)"
echo "  SimB: $SIM_B  ($EMAIL_B)"
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
echo ">>> [1/5] A 가입 + 셋업..."
A_RAW=$(register "$EMAIL_A")
A_TOKEN=$(extract "$A_RAW" 'accessToken')
A_ID=$(extract "$A_RAW" 'user.id')
[ -z "$A_TOKEN" ] && { echo "❌ A 가입 실패: $A_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$A_ID';"
setup_account "$A_TOKEN" "ha" "MOM"

echo ""
echo ">>> [2/5] A 가 FREE 방 생성..."
ROOM_TITLE="2Sim방_${NICK_SUFFIX}"
ROOM_RAW=$(auth_post "$A_TOKEN" "/rooms" "{
  \"title\":\"${ROOM_TITLE}\",
  \"description\":\"2 시뮬 UI e2e 용 방\",
  \"placeType\":\"PLAYGROUND\",
  \"joinType\":\"FREE\",
  \"genderFilter\":\"ALL\",
  \"singleParentOnly\":false,
  \"ageMonthMin\":0,
  \"ageMonthMax\":84,
  \"maxMembers\":10,
  \"date\":\"$TOMORROW\",
  \"startTime\":\"14:00\",
  \"regionSido\":\"서울특별시\",
  \"regionSigungu\":\"강남구\",
  \"regionDong\":\"역삼동\"
}")
ROOM_ID=$(extract "$ROOM_RAW" 'id')
[ -z "$ROOM_ID" ] && { echo "❌ 방 생성 실패: $ROOM_RAW"; exit 1; }
echo "  room.id = $ROOM_ID  title = $ROOM_TITLE"

echo ""
echo ">>> [3/5] B 가입 + 셋업..."
B_RAW=$(register "$EMAIL_B")
B_TOKEN=$(extract "$B_RAW" 'accessToken')
B_ID=$(extract "$B_RAW" 'user.id')
[ -z "$B_TOKEN" ] && { echo "❌ B 가입 실패: $B_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$B_ID';"
setup_account "$B_TOKEN" "hb" "MOM"

echo ""
echo ">>> [4/5] $RESULTS_DIR 초기화..."
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

drive_role() {
  local role="$1" sim="$2" email="$3"
  # 시뮬에 남은 옛 target .app 재사용 방지 — uninstall + BUILD_ID 로 캐시 무효화.
  xcrun simctl uninstall "$sim" kr.kids.app >/dev/null 2>&1 || true
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$sim" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/ui_two_sim_test.dart \
    --dart-define=API_BASE_URL="${API_URL%/v1}" \
    --dart-define=ENVIRONMENT=production \
    --dart-define=UI_TEST_EMAIL="$email" \
    --dart-define=UI_TEST_PASSWORD="$PASSWORD" \
    --dart-define=UI_TEST_ROLE="$role" \
    --dart-define=UI_TARGET_ROOM_TITLE="$ROOM_TITLE" \
    --dart-define=BUILD_ID="twosim-${TS}-${role}-${RANDOM}" 2>&1 | sed "s/^/[$role] /"
}

echo ""
echo ">>> [5/5] Sim A drive (방장)..."
drive_role A "$SIM_A" "$EMAIL_A"

echo ""
echo ">>> Sim B drive (참여자) — A 메시지 보고 답장..."
drive_role B "$SIM_B" "$EMAIL_B"

echo ""
echo "=============================="
echo "  완료. 스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" | sed 's/^/    /'
echo "  A: $EMAIL_A ($A_ID)"
echo "  B: $EMAIL_B ($B_ID)"
echo "  Room: $ROOM_ID / $ROOM_TITLE"
echo "=============================="
