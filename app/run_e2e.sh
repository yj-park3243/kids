#!/bin/bash
# kids 앱 e2e — 시뮬레이터 2대 (A=방장, B=참여자) 병렬 시나리오.
#
# 흐름:
#   1) 두 계정 회원가입 (API)
#   2) SSH+psql 로 is_phone_verified=true UPDATE (KCP 우회)
#   3) A 의 프로필 setup + 아이 등록 + 방 생성 → roomId 추출
#   4) B 의 프로필 setup + 아이 등록 (방 참여는 시뮬레이터 안에서 진행)
#   5) test_results/ 디렉토리 비우기
#   6) flutter drive 를 두 시뮬에서 병렬 실행
#       - 양쪽에 토큰/userId/peerUserId/roomId/ROLE 을 dart-define 으로 주입
#       - 스크린샷은 단일 test_results/ 디렉토리에 평탄 저장
#
# 주의:
#   - TEST_API_BASE_URL 이 prod 를 가리키면 더미 유저/방이 실제 DB 에 쌓임.
#     별도 e2e/stg 환경 권장. 스크립트 하단 클린업 SQL 주석 참고.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── 환경 설정 ─────────────────────────────────────────────────────────
API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
SIM_DEVICE_A="${SIM_DEVICE_A:-iPhone 15}"
SIM_DEVICE_B="${SIM_DEVICE_B:-iPhone 15 Pro}"
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results}"

for bin in curl jq flutter ssh; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 가 PATH 에 없습니다."; exit 1; }
done

TS=$(date +%s)
EMAIL_A="e2e_a_${TS}@test.com"
EMAIL_B="e2e_b_${TS}@test.com"

echo "=============================="
echo "  kids e2e — 2 시뮬레이터 병렬"
echo "  API : $API_URL"
echo "  SimA: $SIM_DEVICE_A  (A: $EMAIL_A)"
echo "  SimB: $SIM_DEVICE_B  (B: $EMAIL_B)"
echo "  Out : $RESULTS_DIR"
echo "=============================="

# ─── helpers ───────────────────────────────────────────────────────────
register() {
  curl -fsS -X POST "$API_URL/auth/email/register" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$PASSWORD\"}"
}

# kids 서버는 envelope `{success, data}` 와 raw 둘 다 쓰는 경우가 있어 둘 다 시도.
extract() {
  local raw="$1" path="$2"
  local v
  v=$(echo "$raw" | jq -r ".data.$path // empty")
  if [ -z "$v" ]; then v=$(echo "$raw" | jq -r ".$path // empty"); fi
  echo "$v"
}

auth_post() {
  # $1 token  $2 path  $3 json
  curl -fsS -X POST "$API_URL$2" \
    -H "Authorization: Bearer $1" \
    -H 'Content-Type: application/json' \
    -d "$3"
}

# ─── 1. 두 계정 회원가입 ───────────────────────────────────────────────
echo ""
echo ">>> [1/6] 두 계정 회원가입..."
RAW_A=$(register "$EMAIL_A")
RAW_B=$(register "$EMAIL_B")

TOKEN_A=$(extract "$RAW_A" 'accessToken')
REFRESH_A=$(extract "$RAW_A" 'refreshToken')
ID_A=$(extract "$RAW_A" 'user.id')

TOKEN_B=$(extract "$RAW_B" 'accessToken')
REFRESH_B=$(extract "$RAW_B" 'refreshToken')
ID_B=$(extract "$RAW_B" 'user.id')

if [ -z "$TOKEN_A$TOKEN_B$ID_A$ID_B" ] || [ -z "$TOKEN_A" ] || [ -z "$ID_A" ] || [ -z "$TOKEN_B" ] || [ -z "$ID_B" ]; then
  echo "❌ 회원가입 응답 파싱 실패"
  echo "A: $RAW_A"
  echo "B: $RAW_B"
  exit 1
fi
echo "  A.id = $ID_A"
echo "  B.id = $ID_B"

# ─── 2. is_phone_verified 우회 ────────────────────────────────────────
echo ""
echo ">>> [2/6] DB 본인인증 우회 (SSH+psql)..."
ssh -i "$SSH_KEY" -o StrictHostKeyChecking=no "$SSH_HOST" "bash -lc '
  set -a; source ~/kids-server/.env; set +a;
  DBURL=\"postgresql://\$DB_USER:\$DB_PASSWORD@\$DB_HOST:\${DB_PORT:-5432}/\$DB_NAME\"
  psql \"\$DBURL\" -v ON_ERROR_STOP=1 -c \"UPDATE \\\"user\\\" SET is_phone_verified = true WHERE id IN ('\''$ID_A'\'', '\''$ID_B'\'');\"
'"

# ─── 3. A 사전 작업: 프로필 + 아이 + 방 생성 ──────────────────────────
echo ""
echo ">>> [3/6] A 의 프로필/아이/방 사전 생성..."
auth_post "$TOKEN_A" "/users/profile" "{\"nickname\":\"e2eA_${TS}\"}" >/dev/null
auth_post "$TOKEN_A" "/children" "{\"nickname\":\"꿈나무A\",\"birthYear\":2022,\"birthMonth\":5,\"gender\":\"MALE\"}" >/dev/null

ROOM_RAW=$(auth_post "$TOKEN_A" "/rooms" "{
  \"title\":\"e2e_${TS}\",
  \"description\":\"e2e 자동화 가 만든 자유 입장 방입니다. 무시해주세요.\",
  \"placeType\":\"PLAYGROUND\",
  \"joinType\":\"FREE\"
}")
ROOM_ID=$(extract "$ROOM_RAW" 'id')
if [ -z "$ROOM_ID" ]; then
  echo "❌ 방 생성 실패. 응답: $ROOM_RAW"
  exit 1
fi
echo "  room.id = $ROOM_ID"

# ─── 4. B 사전 작업: 프로필 + 아이 ────────────────────────────────────
echo ""
echo ">>> [4/6] B 의 프로필/아이 사전 생성..."
auth_post "$TOKEN_B" "/users/profile" "{\"nickname\":\"e2eB_${TS}\"}" >/dev/null
auth_post "$TOKEN_B" "/children" "{\"nickname\":\"꿈나무B\",\"birthYear\":2023,\"birthMonth\":1,\"gender\":\"FEMALE\"}" >/dev/null

# ─── 5. test_results 디렉토리 초기화 ──────────────────────────────────
echo ""
echo ">>> [5/6] $RESULTS_DIR 초기화..."
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# ─── 6. 두 시뮬에서 flutter drive 병렬 실행 ────────────────────────────
echo ""
echo ">>> [6/6] flutter drive 병렬 실행..."

drive_role() {
  local role="$1" device="$2" token="$3" refresh="$4" uid="$5" peer="$6"
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$device" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/main_scenario_test.dart \
    --dart-define=TEST_API_BASE_URL="$API_URL" \
    --dart-define=TEST_USER_ROLE="$role" \
    --dart-define=TEST_ACCESS_TOKEN="$token" \
    --dart-define=TEST_REFRESH_TOKEN="$refresh" \
    --dart-define=TEST_USER_ID="$uid" \
    --dart-define=TEST_PEER_USER_ID="$peer" \
    --dart-define=TEST_PEER_ACCESS_TOKEN="${7:-}" \
    --dart-define=TEST_ROOM_ID="$ROOM_ID" 2>&1 | sed "s/^/[$role] /"
}

drive_role A "$SIM_DEVICE_A" "$TOKEN_A" "$REFRESH_A" "$ID_A" "$ID_B" "$TOKEN_B" &
PID_A=$!
drive_role B "$SIM_DEVICE_B" "$TOKEN_B" "$REFRESH_B" "$ID_B" "$ID_A" "$TOKEN_A" &
PID_B=$!

set +e
wait "$PID_A"; EXIT_A=$?
wait "$PID_B"; EXIT_B=$?
set -e

echo ""
echo "=============================="
echo "  A exit=$EXIT_A   B exit=$EXIT_B"
echo "  스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" 2>/dev/null | sed 's/^/    /'
echo "  생성된 더미: user $ID_A, user $ID_B, room $ROOM_ID"
echo "=============================="

if [ "$EXIT_A" != "0" ] || [ "$EXIT_B" != "0" ]; then
  exit 1
fi

# ─── (선택) 클린업 ──────────────────────────────────────────────────
# 운영 DB 오염 방지를 위해 끝나면 직접 지우세요. 테이블명은 entity 정의에 맞춰 조정:
#   DELETE FROM chat_message WHERE room_id = '$ROOM_ID';
#   DELETE FROM room_member  WHERE room_id = '$ROOM_ID';
#   DELETE FROM room         WHERE id = '$ROOM_ID';
#   DELETE FROM user_report  WHERE reporter_id IN ('$ID_A','$ID_B');
#   DELETE FROM child        WHERE user_id   IN ('$ID_A','$ID_B');
#   DELETE FROM "user"       WHERE id        IN ('$ID_A','$ID_B');
