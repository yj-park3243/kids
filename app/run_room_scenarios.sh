#!/bin/bash
# 2-sim 방 입장 / 한부모 시나리오 — match3(한부모 방장 A) + match4(일반 부모 B).
#
# 방식(사용자 요청): DB 강제 본인인증 → 서버 토큰 → dart-define 주입 → 앱 자동 로그인.
#   1) A(한부모)/B(일반) 가입(API) → register 응답에서 토큰 확보
#   2) SSH+psql 로 is_phone_verified=true (bypass off 됐으므로 테스트는 DB 강제)
#   3) 프로필 setup — A: MOM/single=true, B: MOM/single=false
#   4) A 토큰으로 방 3개 생성 — room1(FREE/ALL), room2(APPROVAL/ALL), room3(FREE/한부모)
#   5) 순차 drive: match4(B, 신청) → match3(A, 승인). 토큰 dart-define 자동 로그인.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
SIM_A="${SIM_A:-ED66A1C7-690A-4CA3-8263-ECE3015883B8}"   # match3 — 한부모 방장
SIM_B="${SIM_B:-0CB749D9-5029-42AE-982C-F5CEDD5336BE}"   # match4 — 일반 부모
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results}"

for bin in curl jq flutter ssh; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 없음"; exit 1; }
done

TS=$(date +%s)
EMAIL_A="rsa_${TS}@test.com"   # 한부모
EMAIL_B="rsb_${TS}@test.com"   # 일반
NICK_SUFFIX="${TS: -6}"
TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

echo "=============================="
echo "  2-sim 방/한부모 시나리오"
echo "  match3(A 한부모): $SIM_A / $EMAIL_A"
echo "  match4(B 일반):   $SIM_B / $EMAIL_B"
echo "=============================="

register() {
  curl -fsS -X POST "$API_URL/auth/email/register" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$PASSWORD\"}"
}
extract() {
  local r="$1" p="$2" v
  v=$(echo "$r" | jq -r ".data.$p // empty")
  [ -z "$v" ] && v=$(echo "$r" | jq -r ".$p // empty")
  echo "$v"
}
auth_post() {
  curl -fsS -X POST "$API_URL$2" \
    -H "Authorization: Bearer $1" -H 'Content-Type: application/json' -d "$3"
}
ssh_psql() {
  local sql="$1" b64
  b64=$(printf '%s' "$sql" | base64 | tr -d '\n')
  ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_HOST" bash <<EOF
set -a; source ~/kids-server/.env.production 2>/dev/null || source ~/kids-server/.env; set +a
DECODED=\$(echo "$b64" | base64 -d)
psql "postgresql://\$DB_USER:\$DB_PASSWORD@\$DB_HOST:\${DB_PORT:-5432}/\$DB_NAME" \
  -v ON_ERROR_STOP=1 -c "\$DECODED"
EOF
}

echo ""
echo ">>> [1/5] A(한부모)/B(일반) 가입..."
RAW_A=$(register "$EMAIL_A"); TOKEN_A=$(extract "$RAW_A" 'accessToken'); REFRESH_A=$(extract "$RAW_A" 'refreshToken'); ID_A=$(extract "$RAW_A" 'user.id')
RAW_B=$(register "$EMAIL_B"); TOKEN_B=$(extract "$RAW_B" 'accessToken'); REFRESH_B=$(extract "$RAW_B" 'refreshToken'); ID_B=$(extract "$RAW_B" 'user.id')
if [ -z "$TOKEN_A" ] || [ -z "$TOKEN_B" ]; then echo "❌ 가입 실패: A=$RAW_A B=$RAW_B"; exit 1; fi
echo "  A.id=$ID_A  B.id=$ID_B"

echo ""
echo ">>> [2/5] DB 강제 본인인증 (SSH+psql)..."
ssh_psql "UPDATE \"user\" SET is_phone_verified=true WHERE id IN ('$ID_A','$ID_B');"

echo ""
echo ">>> [3/5] 프로필 setup (A 한부모 / B 일반)..."
auth_post "$TOKEN_A" "/users/profile" "{\"nickname\":\"rsA${NICK_SUFFIX}\",\"parentGender\":\"MOM\",\"isSingleParent\":true,\"regionSido\":\"서울특별시\",\"regionSigungu\":\"강남구\",\"regionDong\":\"역삼동\"}" >/dev/null
auth_post "$TOKEN_B" "/users/profile" "{\"nickname\":\"rsB${NICK_SUFFIX}\",\"parentGender\":\"MOM\",\"isSingleParent\":false,\"regionSido\":\"서울특별시\",\"regionSigungu\":\"강남구\",\"regionDong\":\"역삼동\"}" >/dev/null
auth_post "$TOKEN_A" "/children" '{"nickname":"A아이","birthYear":2022,"birthMonth":5,"gender":"MALE"}' >/dev/null
auth_post "$TOKEN_B" "/children" '{"nickname":"B아이","birthYear":2023,"birthMonth":3,"gender":"FEMALE"}' >/dev/null

echo ""
echo ">>> [4/5] 방 3개 생성 (A 호스트)..."
create_room() {
  # $1 title  $2 joinType  $3 singleParentOnly
  auth_post "$TOKEN_A" "/rooms" "{
    \"title\":\"$1\",\"description\":\"2sim $1\",\"placeType\":\"PLAYGROUND\",
    \"placeName\":\"역삼공원\",\"placeAddress\":\"서울 강남구 역삼동\",
    \"joinType\":\"$2\",\"genderFilter\":\"ALL\",\"singleParentOnly\":$3,
    \"ageMonthMin\":0,\"ageMonthMax\":84,\"maxMembers\":5,
    \"date\":\"$TOMORROW\",\"startTime\":\"14:00\",
    \"regionSido\":\"서울특별시\",\"regionSigungu\":\"강남구\",\"regionDong\":\"역삼동\"
  }"
}
R1=$(create_room "2sR1자유_${NICK_SUFFIX}" "FREE" "false");      ROOM1=$(extract "$R1" 'id')
R2=$(create_room "2sR2승인_${NICK_SUFFIX}" "APPROVAL" "false");  ROOM2=$(extract "$R2" 'id')
R3=$(create_room "2sR3한부모_${NICK_SUFFIX}" "FREE" "true");     ROOM3=$(extract "$R3" 'id')
if [ -z "$ROOM1$ROOM2$ROOM3" ]; then echo "❌ 방 생성 실패: $R1 / $R2 / $R3"; exit 1; fi
echo "  room1=$ROOM1 (자유)  room2=$ROOM2 (승인)  room3=$ROOM3 (한부모)"

rm -rf "$RESULTS_DIR"; mkdir -p "$RESULTS_DIR"

drive_role() {
  local role="$1" device="$2" token="$3" refresh="$4" uid="$5" single="$6"
  xcrun simctl uninstall "$device" kr.kids.app >/dev/null 2>&1 || true
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$device" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/room_scenarios_test.dart \
    --dart-define=TEST_API_BASE_URL="$API_URL" \
    --dart-define=API_BASE_URL="${API_URL%/v1}" \
    --dart-define=ENVIRONMENT=production \
    --dart-define=TEST_USER_ROLE="$role" \
    --dart-define=TEST_ACCESS_TOKEN="$token" \
    --dart-define=TEST_REFRESH_TOKEN="$refresh" \
    --dart-define=TEST_USER_ID="$uid" \
    --dart-define=TEST_ROOM_ID_1="$ROOM1" \
    --dart-define=TEST_ROOM_ID_2="$ROOM2" \
    --dart-define=TEST_ROOM_ID_3="$ROOM3" \
    --dart-define=TEST_IS_SINGLE_PARENT="$single" \
    --dart-define=BUILD_ID="rs-${TS}-${role}-${RANDOM}" 2>&1 | sed "s/^/[$role] /"
}

echo ""
echo ">>> [5/5] drive — match4(B 일반, 신청) → match3(A 한부모, 승인)..."
set +e
drive_role B "$SIM_B" "$TOKEN_B" "$REFRESH_B" "$ID_B" "false"; EXIT_B=$?
drive_role A "$SIM_A" "$TOKEN_A" "$REFRESH_A" "$ID_A" "true";  EXIT_A=$?
set -e

echo ""
echo "=============================="
echo "  완료. A exit=$EXIT_A  B exit=$EXIT_B"
echo "  스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" 2>/dev/null | sed 's/^/    /'
echo "  users: A(한부모)=$ID_A  B(일반)=$ID_B"
echo "  rooms: 자유=$ROOM1  승인=$ROOM2  한부모=$ROOM3"
echo "=============================="
if [ "$EXIT_A" != "0" ] || [ "$EXIT_B" != "0" ]; then exit 1; fi
