#!/bin/bash
# 3 시뮬 UI e2e — 방장(A) + 수락되는 참여자(B) + 거절되는 참여자(C).
#
# 흐름:
#   1) A/B/C 세 계정 가입 + 폰인증 + 프로필 + 자녀
#   2) A 토큰으로 '승인 필요(APPROVAL)' 방 사전 생성
#   3) 시뮬 3대 부팅
#   4) 순차 drive: B1(신청) → C1(신청) → A2(수락/거절/채팅) → B3(채팅/나가기) → C3(재신청/취소)
#
# 비동기 흐름(신청 → 방장 처리 → 결과 확인)이라 역할마다 단계를 나눠 여러 번 drive 한다.
# 시뮬 동시 빌드는 race 가 나므로 순차 실행한다.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
# 사용 가능한 시뮬레이터 UDID (xcrun simctl list devices available)
SIM_A="${SIM_A:-447803FE-BD81-4025-A533-BB4099269D6E}"   # iPhone 17 Pro
SIM_B="${SIM_B:-72277065-7CE6-4908-82AE-3C6DBE39FF4C}"   # iPhone 17
SIM_C="${SIM_C:-8A887310-8A63-45AD-A1ED-A269ACA8B654}"   # iPhone 17e
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results_3sim}"
LOG_DIR="$RESULTS_DIR/logs"
BUNDLE_ID="${BUNDLE_ID:-kr.kids.app}"
PLACE_NAME="${PLACE_NAME:-역삼 어린이공원}"
# 1 이면 실행 후 테스트 계정/방을 남긴다(단일 패스 재현 디버깅용).
KEEP_TEST_DATA="${KEEP_TEST_DATA:-0}"
EXIT_CODE=0
FAILED_LIST=""

for bin in curl jq flutter ssh xcrun; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 없음"; exit 1; }
done

TS=$(date +%s)
EMAIL_A="ui3a_${TS}@test.com"
EMAIL_B="ui3b_${TS}@test.com"
EMAIL_C="ui3c_${TS}@test.com"
SUF="${TS: -6}"
NICK_A="방장A${SUF}"
NICK_B="참여B${SUF}"
NICK_C="거절C${SUF}"
TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

echo "=============================="
echo "  3-sim UI e2e"
echo "  API : $API_URL"
echo "  SimA: $SIM_A ($EMAIL_A / $NICK_A)"
echo "  SimB: $SIM_B ($EMAIL_B / $NICK_B)"
echo "  SimC: $SIM_C ($EMAIL_C / $NICK_C)"
echo "=============================="

ssh_psql() {
  local sql="$1" flags="${2:-}" b64
  b64=$(printf '%s' "$sql" | base64 | tr -d '\n')
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_HOST" bash <<EOF
set -a
source ~/kids-server/.env.production || { echo '❌ .env.production 없음'; exit 1; }
set +a
DECODED=\$(echo "$b64" | base64 -d)
psql "postgresql://\$DB_USER:\$DB_PASSWORD@\$DB_HOST:\${DB_PORT:-5432}/\$DB_NAME" \
  -v ON_ERROR_STOP=1 $flags -c "\$DECODED"
EOF
}

# 한 값만 필요할 때 — 헤더/공백 없이 마지막 줄만.
ssh_psql_scalar() { ssh_psql "$1" "-tA" | tr -d '\r' | tail -1; }

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

auth_get() {
  curl -fsS "$API_URL$2" -H "Authorization: Bearer $1"
}

setup_account() {
  local token="$1" nick="$2"
  auth_post "$token" "/users/profile" "{
    \"nickname\":\"$nick\",
    \"parentGender\":\"MOM\",
    \"isSingleParent\":false,
    \"regionSido\":\"서울특별시\",
    \"regionSigungu\":\"강남구\",
    \"regionDong\":\"역삼동\"
  }" >/dev/null
  auth_post "$token" "/children" \
    '{"nickname":"아이","birthYear":2023,"birthMonth":11,"gender":"FEMALE"}' \
    >/dev/null
}

make_account() {
  local email="$1" nick="$2" raw token id
  raw=$(register "$email")
  token=$(extract "$raw" 'accessToken')
  id=$(extract "$raw" 'user.id')
  [ -z "$token" ] && { echo "❌ 가입 실패($email): $raw" >&2; exit 1; }
  ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id='$id';" >/dev/null
  setup_account "$token" "$nick"
  echo "$token $id"
}

echo ""
echo ">>> [1/5] 계정 3개 생성..."
read -r A_TOKEN A_ID <<<"$(make_account "$EMAIL_A" "$NICK_A")"
read -r B_TOKEN B_ID <<<"$(make_account "$EMAIL_B" "$NICK_B")"
read -r C_TOKEN C_ID <<<"$(make_account "$EMAIL_C" "$NICK_C")"
echo "  A=$A_ID  B=$B_ID  C=$C_ID"

echo ""
echo ">>> [2/5] A 가 '승인 필요' 방 생성..."
ROOM_TITLE="3Sim승인방_${SUF}"
ROOM_RAW=$(auth_post "$A_TOKEN" "/rooms" "{
  \"title\":\"${ROOM_TITLE}\",
  \"description\":\"3 시뮬 UI e2e 용 승인제 모임입니다. 수락/거절/채팅/나가기를 확인합니다.\",
  \"placeType\":\"PLAYGROUND\",
  \"joinType\":\"APPROVAL\",
  \"genderFilter\":\"ALL\",
  \"singleParentOnly\":false,
  \"ageMonthMin\":0,
  \"ageMonthMax\":84,
  \"maxMembers\":10,
  \"date\":\"$TOMORROW\",
  \"startTime\":\"14:00\",
  \"endTime\":\"16:00\",
  \"regionSido\":\"서울특별시\",
  \"regionSigungu\":\"강남구\",
  \"regionDong\":\"역삼동\",
  \"placeName\":\"${PLACE_NAME}\",
  \"placeAddress\":\"서울특별시 강남구 역삼동 736\"
}")
ROOM_ID=$(extract "$ROOM_RAW" 'id')
[ -z "$ROOM_ID" ] && { echo "❌ 방 생성 실패: $ROOM_RAW"; exit 1; }
echo "  room.id = $ROOM_ID  title = $ROOM_TITLE"

echo ""
echo ">>> [3/5] 결과 디렉터리 초기화 + 시뮬 부팅..."
rm -rf "$RESULTS_DIR"
mkdir -p "$LOG_DIR"
for sim in "$SIM_A" "$SIM_B" "$SIM_C"; do
  xcrun simctl boot "$sim" 2>/dev/null || true
done
open -a Simulator 2>/dev/null || true
sleep 5

drive() {
  local role="$1" phase="$2" sim="$3" email="$4"
  local tag="${role}${phase}"
  echo ""
  echo ">>> drive $tag (sim=$sim)"
  # 시뮬에 남은 옛 .app 재사용 방지 — uninstall + BUILD_ID 로 캐시 무효화.
  xcrun simctl uninstall "$sim" "$BUNDLE_ID" >/dev/null 2>&1 || true
  set +e
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$sim" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/ui_three_sim_test.dart \
    --dart-define=API_BASE_URL="${API_URL%/v1}" \
    --dart-define=ENVIRONMENT=production \
    --dart-define=UI_TEST_EMAIL="$email" \
    --dart-define=UI_TEST_PASSWORD="$PASSWORD" \
    --dart-define=UI_TEST_ROLE="$role" \
    --dart-define=UI_TEST_PHASE="$phase" \
    --dart-define=UI_TARGET_ROOM_ID="$ROOM_ID" \
    --dart-define=UI_TARGET_ROOM_TITLE="$ROOM_TITLE" \
    --dart-define=UI_TARGET_PLACE_NAME="$PLACE_NAME" \
    --dart-define=UI_NICK_B="$NICK_B" \
    --dart-define=UI_NICK_C="$NICK_C" \
    --dart-define=BUILD_ID="3sim-${TS}-${tag}" \
    >"$LOG_DIR/$tag.log" 2>&1
  local rc=$?
  set -e
  grep -E "\[E2E\]" "$LOG_DIR/$tag.log" | sed 's/^flutter: //' | sed "s/^/    /" || true
  echo "    (exit=$rc, log=$LOG_DIR/$tag.log)"
  if [ "$rc" -ne 0 ]; then
    FAILED_LIST="$FAILED_LIST $tag"
    EXIT_CODE=1
  fi
}

echo ""
echo ">>> [4/5] 순차 실행..."
drive B 1 "$SIM_B" "$EMAIL_B"   # B 참여 신청
drive C 1 "$SIM_C" "$EMAIL_C"   # C 참여 신청
drive A 2 "$SIM_A" "$EMAIL_A"   # 방장: B 수락 / C 거절 + 채팅
drive B 3 "$SIM_B" "$EMAIL_B"   # B: 채팅 답장 + 모임 나가기
drive C 3 "$SIM_C" "$EMAIL_C"   # C: 재신청 + 신청 취소

echo ""
echo ">>> [5/6] 서버 최종 상태 검증..."
# 액세스 토큰은 만료될 수 있어 최종 확인은 DB 로 직접 한다.
ACTUAL_ROOM=$(ssh_psql_scalar "SELECT r.status || '|' || r.current_members FROM room r WHERE r.id='$ROOM_ID';")
ACTUAL_REQ=$(ssh_psql_scalar "SELECT COALESCE(string_agg(jr.status, ',' ORDER BY jr.status), '') FROM join_request jr WHERE jr.room_id='$ROOM_ID';")
# 기대: B 가 수락됐다가 나가고(CANCELLED), C 는 거절 후 재신청분을 취소(REJECTED+CANCELLED).
#       방은 방장만 남아 모집중.
EXPECT_ROOM="RECRUITING|1"
EXPECT_REQ="CANCELLED,CANCELLED,REJECTED"
echo "  방/멤버      : $ACTUAL_ROOM   (기대 $EXPECT_ROOM)"
echo "  참여 신청    : $ACTUAL_REQ   (기대 $EXPECT_REQ)"
if [ "$ACTUAL_ROOM" != "$EXPECT_ROOM" ] || [ "$ACTUAL_REQ" != "$EXPECT_REQ" ]; then
  echo "  ❌ 최종 서버 상태가 기대와 다르다"
  EXIT_CODE=1
else
  echo "  ✅ 서버 상태 일치"
fi

echo ""
echo ">>> [6/6] 정리..."
if [ "$KEEP_TEST_DATA" = "1" ]; then
  echo "  KEEP_TEST_DATA=1 — 계정/방을 남긴다"
else
  # 방을 먼저 취소한다 — 모집중으로 두면 실제 사용자의 '모임 찾기'/지도에 노출된다.
  if curl -fsS -X DELETE "$API_URL/rooms/$ROOM_ID" \
      -H "Authorization: Bearer $A_TOKEN" >/dev/null 2>&1; then
    echo "  방 취소 완료 (API)"
  else
    ssh_psql "UPDATE room SET status='CANCELLED' WHERE id='$ROOM_ID';" >/dev/null 2>&1 \
      && echo "  방 취소 완료 (DB 폴백)" || echo "  ⚠️  방 취소 실패 — 수동 확인 필요: $ROOM_ID"
  fi
  # 테스트 계정 제거(방/멤버/메시지는 FK CASCADE). 제약에 걸리면 경고만 남긴다.
  if ssh_psql "DELETE FROM \"user\" WHERE id IN ('$A_ID','$B_ID','$C_ID');" >/dev/null 2>&1; then
    echo "  테스트 계정 3개 삭제 완료"
  else
    echo "  ⚠️  계정 삭제 실패 — 남은 계정: $EMAIL_A / $EMAIL_B / $EMAIL_C"
  fi
fi

echo ""
echo "=============================="
echo "  결과 요약"
grep -hE "\[E2E\]\[.*\]\[RESULT\]" "$LOG_DIR"/*.log | sed 's/^flutter: //' | sed 's/^/    /' || echo "    (RESULT 라인 없음)"
echo ""
if [ -n "$FAILED_LIST" ]; then
  echo "  ❌ 실패한 패스:$FAILED_LIST"
fi
echo "  로그: $LOG_DIR"
echo "  Room: $ROOM_ID / $ROOM_TITLE"
echo "  A: $EMAIL_A / B: $EMAIL_B / C: $EMAIL_C"
if [ "$EXIT_CODE" -eq 0 ]; then
  echo "  ✅ 전체 통과"
else
  echo "  ❌ 실패 있음 (exit $EXIT_CODE)"
fi
echo "=============================="
exit $EXIT_CODE
