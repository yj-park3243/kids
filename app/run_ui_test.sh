#!/bin/bash
# UI 자동화 풀 e2e — 로그인 → 방 만들기 진입 → 입장 → 채팅까지.
#
# 흐름:
#   1) HOST 계정 가입 + 폰인증 + 프로필 + 자녀 + FREE 방 생성
#   2) USER 계정 가입 + 폰인증 + 프로필 + 자녀 (테스트 주체)
#   3) test_results 초기화
#   4) flutter drive ui_full_test (UI tap/enterText)
#
# USER 가 UI 로 로그인 → 홈에서 HOST 가 만든 방을 입장 → 채팅.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
SIM_DEVICE="${SIM_DEVICE:-1CCE8E44-C182-4137-8E1A-CB67CBD1CC0B}"
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results}"

for bin in curl jq flutter ssh; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 없음"; exit 1; }
done

TS=$(date +%s)
HOST_EMAIL="uihost_${TS}@test.com"
USER_EMAIL="uiuser_${TS}@test.com"
NICK_SUFFIX="${TS: -6}"
TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

echo "=============================="
echo "  UI 풀 e2e — 1 시뮬"
echo "  API : $API_URL"
echo "  Sim : $SIM_DEVICE"
echo "  HOST: $HOST_EMAIL"
echo "  USER: $USER_EMAIL"
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
  # $1 token  $2 nickPrefix  $3 parentGender
  auth_post "$1" "/users/profile" "{
    \"nickname\":\"$2${NICK_SUFFIX}\",
    \"parentGender\":\"$3\",
    \"isSingleParent\":false,
    \"regionSido\":\"서울특별시\",
    \"regionSigungu\":\"강남구\",
    \"regionDong\":\"역삼동\"
  }" >/dev/null
  # 30개월 전후 — 우리 방(0~84) 과 사용자가 직접 만든 방(예: 27~33) 모두 매칭.
  auth_post "$1" "/children" \
    '{"nickname":"아이","birthYear":2023,"birthMonth":11,"gender":"FEMALE"}' \
    >/dev/null
}

echo ""
echo ">>> [1/5] HOST 가입 + 셋업..."
HOST_RAW=$(register "$HOST_EMAIL")
HOST_TOKEN=$(extract "$HOST_RAW" 'accessToken')
HOST_ID=$(extract "$HOST_RAW" 'user.id')
[ -z "$HOST_TOKEN" ] && { echo "❌ HOST 가입 실패: $HOST_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$HOST_ID';"
setup_account "$HOST_TOKEN" "uh" "MOM"

echo ""
echo ">>> [2/5] HOST 가 FREE 방 생성..."
ROOM_TITLE="UI테스트방_${NICK_SUFFIX}"
ROOM_RAW=$(auth_post "$HOST_TOKEN" "/rooms" "{
  \"title\":\"${ROOM_TITLE}\",
  \"description\":\"UI 자동화 e2e 용 자유입장 방\",
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
echo "  room.id = $ROOM_ID"

echo ""
echo ">>> [3/5] USER 가입 + 셋업..."
USER_RAW=$(register "$USER_EMAIL")
USER_TOKEN=$(extract "$USER_RAW" 'accessToken')
USER_ID=$(extract "$USER_RAW" 'user.id')
[ -z "$USER_TOKEN" ] && { echo "❌ USER 가입 실패: $USER_RAW"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$USER_ID';"
setup_account "$USER_TOKEN" "uu" "MOM"

echo ""
echo ">>> [4/5] $RESULTS_DIR 초기화..."
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

echo ""
echo ">>> [5/5] flutter drive — UI 풀 시나리오..."
TEST_RESULTS_DIR="$RESULTS_DIR" SIM_UDID="$SIM_DEVICE" flutter drive \
  -d "$SIM_DEVICE" \
  --driver=test_driver/integration_test.dart \
  --target=integration_test/ui_full_test.dart \
  --dart-define=API_BASE_URL="${API_URL%/v1}" \
  --dart-define=ENVIRONMENT=production \
  --dart-define=UI_TEST_EMAIL="$USER_EMAIL" \
  --dart-define=UI_TEST_PASSWORD="$PASSWORD" \
  --dart-define=UI_TARGET_ROOM_TITLE="$ROOM_TITLE"

echo ""
echo "=============================="
echo "  완료. 스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" | sed 's/^/    /'
echo "  HOST: $HOST_EMAIL ($HOST_ID) / room $ROOM_ID"
echo "  USER: $USER_EMAIL ($USER_ID)"
echo "=============================="
