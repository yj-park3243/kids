#!/bin/bash
# 2 시뮬 UI 자동화 — 승인 방(APPROVAL) 신청 → 승인 흐름.
#
# 흐름:
#   1) A/B 가입 + 셋업
#   2) A 토큰으로 APPROVAL 방 사전 생성
#   3) Sim B 먼저 drive (신청 → PENDING 캡처)
#   4) Sim A drive (⋮ → 참여 관리 → 수락)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
SIM_A="${SIM_A:-1CCE8E44-C182-4137-8E1A-CB67CBD1CC0B}"
SIM_B="${SIM_B:-973A77C8-1724-4105-8197-7E1B60CEA4AF}"
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results}"

for bin in curl jq flutter ssh; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 없음"; exit 1; }
done

TS=$(date +%s)
EMAIL_A="apa_${TS}@test.com"
EMAIL_B="apb_${TS}@test.com"
NICK_SUFFIX="${TS: -6}"
TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

echo "=============================="
echo "  Approval 2-sim e2e"
echo "  API: $API_URL"
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
extract() { echo "$1" | jq -r ".data.$2 // .$2 // empty"; }
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
echo ">>> [1/4] A/B 가입 + 셋업..."
A_RAW=$(register "$EMAIL_A")
A_TOKEN=$(extract "$A_RAW" 'accessToken')
A_ID=$(extract "$A_RAW" 'user.id')
B_RAW=$(register "$EMAIL_B")
B_TOKEN=$(extract "$B_RAW" 'accessToken')
B_ID=$(extract "$B_RAW" 'user.id')
[ -z "$A_TOKEN" ] || [ -z "$B_TOKEN" ] && { echo "❌ 가입 실패"; exit 1; }
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id IN ('$A_ID','$B_ID');"
setup_account "$A_TOKEN" "ap" "MOM"
setup_account "$B_TOKEN" "bp" "MOM"

echo ""
echo ">>> [2/4] A 가 APPROVAL 방 생성..."
ROOM_TITLE="승인방_${NICK_SUFFIX}"
ROOM_RAW=$(auth_post "$A_TOKEN" "/rooms" "{
  \"title\":\"${ROOM_TITLE}\",
  \"description\":\"승인 방 e2e\",
  \"placeType\":\"PLAYGROUND\",
  \"joinType\":\"APPROVAL\",
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
echo "  room.id=$ROOM_ID  title=$ROOM_TITLE"

echo ""
echo ">>> [3/4] $RESULTS_DIR 초기화..."
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

drive_role() {
  local role="$1" sim="$2" email="$3" target_uid="${4:-}"
  # 이전 target 의 .app 캐시가 시뮬·flutter build 양쪽에 남아 옛 빌드가
  # 재사용되는 문제 회피.
  xcrun simctl uninstall "$sim" kr.kids.app >/dev/null 2>&1 || true
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$sim" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/ui_approval_test.dart \
    --dart-define=API_BASE_URL="${API_URL%/v1}" \
    --dart-define=ENVIRONMENT=production \
    --dart-define=UI_TEST_EMAIL="$email" \
    --dart-define=UI_TEST_PASSWORD="$PASSWORD" \
    --dart-define=UI_TEST_ROLE="$role" \
    --dart-define=UI_TARGET_ROOM_TITLE="$ROOM_TITLE" \
    --dart-define=UI_APPROVE_TARGET_USER_ID="$target_uid" \
    --dart-define=BUILD_ID="approval-${TS}-${role}-${RANDOM}" 2>&1 | sed "s/^/[$role] /"
}

echo ""
echo ">>> [4/4] Sim B drive (신청)..."
drive_role B "$SIM_B" "$EMAIL_B"

echo ""
echo ">>> Sim A drive (수락) — 대상 user $B_ID..."
drive_role A "$SIM_A" "$EMAIL_A" "$B_ID"

echo ""
echo "=============================="
echo "  완료. 스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" | sed 's/^/    /'
echo "  Room: $ROOM_ID / $ROOM_TITLE"
echo "  A: $EMAIL_A ($A_ID) / B: $EMAIL_B ($B_ID)"
echo "=============================="
