#!/bin/bash
# kids 앱 e2e — 시뮬레이터 3대(A/B/C) 병렬, 3 round 시나리오.
#
# 흐름:
#   1) A/B/C 세 계정 회원가입 (API)
#   2) SSH+psql 로 is_phone_verified=true UPDATE (KCP 우회)
#   3) 프로필 setup
#       - A: nickname A, MOM, isSingleParent=true
#       - B: nickname B, MOM, isSingleParent=true
#       - C: nickname C, DAD, isSingleParent=false
#       (자녀는 A 2명, B 2명, C 4명)
#   4) Round 별 방 사전 생성 (모두 A 가 호스트)
#       - room1: FREE / ALL / not single-parent only
#       - room2: APPROVAL / MOM_ONLY / not single-parent only
#       - room3: FREE / ALL / singleParentOnly=true
#   5) Round 1 후기를 가능하게 하기 위해 room1.status = COMPLETED + completed_at = NOW()
#       — 멤버 join 은 시뮬레이터 안에서 발생하므로 후기 작성 직전이 아니라
#         orchestrator 가 일정 시간 대기 후 UPDATE 한다. 단순화를 위해 사전에
#         미리 처리하고, 시뮬에서 join 후 채팅을 보내는 식으로 진행.
#         완료 상태 UPDATE 는 orchestrator 끝부분의 sleep 후 처리.
#   6) test_results/ 디렉토리 비우기
#   7) 3 시뮬에서 flutter drive 병렬 실행 (UDID 직접 지정 가능)
#
# 주의:
#   - 운영 서버에 더미 데이터가 쌓일 수 있다. 클린업 SQL 은 스크립트 하단 참고.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

# ─── 환경 설정 ─────────────────────────────────────────────────────────
API_URL="${TEST_API_BASE_URL:-https://api.growtogether.kr/v1}"
SSH_KEY="${KIDS_SSH_KEY:-$SCRIPT_DIR/../kids-key.pem}"
SSH_HOST="${KIDS_SSH_HOST:-ubuntu@43.201.221.240}"
# 시뮬레이터 — 이름 또는 UDID. flutter drive 가 직접 받음.
SIM_DEVICE_A="${SIM_DEVICE_A:-1CCE8E44-C182-4137-8E1A-CB67CBD1CC0B}"   # kids
SIM_DEVICE_B="${SIM_DEVICE_B:-973A77C8-1724-4105-8197-7E1B60CEA4AF}"   # iPhone 17
SIM_DEVICE_C="${SIM_DEVICE_C:-4F6D9DBC-731E-4203-9310-4311ABE8A9E5}"   # match
PASSWORD="${E2E_PASSWORD:-Test1234!}"
RESULTS_DIR="${TEST_RESULTS_DIR:-$SCRIPT_DIR/test_results}"

for bin in curl jq flutter ssh; do
  command -v "$bin" >/dev/null 2>&1 || { echo "❌ $bin 가 PATH 에 없습니다."; exit 1; }
done

TS=$(date +%s)
EMAIL_A="e2e_a_${TS}@test.com"
EMAIL_B="e2e_b_${TS}@test.com"
EMAIL_C="e2e_c_${TS}@test.com"
# nickname 은 maxLength 10 — TS 의 뒷 6자리만 사용해 unique 한 짧은 이름 생성.
NICK_SUFFIX="${TS: -6}"

echo "=============================="
echo "  kids e2e — 3 시뮬레이터 / 3 round"
echo "  API : $API_URL"
echo "  SimA: $SIM_DEVICE_A  (A: $EMAIL_A, MOM, single)"
echo "  SimB: $SIM_DEVICE_B  (B: $EMAIL_B, MOM, single)"
echo "  SimC: $SIM_DEVICE_C  (C: $EMAIL_C, DAD, normal)"
echo "  Out : $RESULTS_DIR"
echo "=============================="

# ─── helpers ───────────────────────────────────────────────────────────
register() {
  curl -fsS -X POST "$API_URL/auth/email/register" \
    -H 'Content-Type: application/json' \
    -d "{\"email\":\"$1\",\"password\":\"$PASSWORD\"}"
}

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

ssh_psql() {
  # SQL 의 ' / " / \\ 가 ssh/bash quote 처리에서 자주 깨져 base64 로 안전 전달.
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

# ─── 1. 세 계정 회원가입 ───────────────────────────────────────────────
echo ""
echo ">>> [1/7] 세 계정 회원가입..."
RAW_A=$(register "$EMAIL_A")
RAW_B=$(register "$EMAIL_B")
RAW_C=$(register "$EMAIL_C")

TOKEN_A=$(extract "$RAW_A" 'accessToken')
REFRESH_A=$(extract "$RAW_A" 'refreshToken')
ID_A=$(extract "$RAW_A" 'user.id')

TOKEN_B=$(extract "$RAW_B" 'accessToken')
REFRESH_B=$(extract "$RAW_B" 'refreshToken')
ID_B=$(extract "$RAW_B" 'user.id')

TOKEN_C=$(extract "$RAW_C" 'accessToken')
REFRESH_C=$(extract "$RAW_C" 'refreshToken')
ID_C=$(extract "$RAW_C" 'user.id')

if [ -z "$TOKEN_A" ] || [ -z "$TOKEN_B" ] || [ -z "$TOKEN_C" ]; then
  echo "❌ 회원가입 응답 파싱 실패"
  echo "A: $RAW_A"
  echo "B: $RAW_B"
  echo "C: $RAW_C"
  exit 1
fi
echo "  A.id = $ID_A"
echo "  B.id = $ID_B"
echo "  C.id = $ID_C"

# ─── 2. 폰인증 우회 (한부모도 같이 UPDATE 가능하지만 profile API 로 처리) ─
echo ""
echo ">>> [2/7] DB 본인인증 우회 (SSH+psql)..."
ssh_psql "UPDATE \"user\" SET is_phone_verified = true WHERE id IN ('$ID_A', '$ID_B', '$ID_C');"

# ─── 3. 프로필 setup (parentGender / isSingleParent 포함) ─────────────
echo ""
echo ">>> [3/7] 프로필 setup..."
auth_post "$TOKEN_A" "/users/profile" "{
  \"nickname\":\"eA${NICK_SUFFIX}\",
  \"parentGender\":\"MOM\",
  \"isSingleParent\":true,
  \"regionSido\":\"서울특별시\",
  \"regionSigungu\":\"강남구\",
  \"regionDong\":\"역삼동\"
}" >/dev/null
auth_post "$TOKEN_B" "/users/profile" "{
  \"nickname\":\"eB${NICK_SUFFIX}\",
  \"parentGender\":\"MOM\",
  \"isSingleParent\":true,
  \"regionSido\":\"서울특별시\",
  \"regionSigungu\":\"강남구\",
  \"regionDong\":\"역삼동\"
}" >/dev/null
auth_post "$TOKEN_C" "/users/profile" "{
  \"nickname\":\"eC${NICK_SUFFIX}\",
  \"parentGender\":\"DAD\",
  \"isSingleParent\":false,
  \"regionSido\":\"서울특별시\",
  \"regionSigungu\":\"강남구\",
  \"regionDong\":\"역삼동\"
}" >/dev/null

# 자녀 등록 — A 2명, B 2명, C 4명.
add_child() {
  # $1 token  $2 nickname  $3 year  $4 month  $5 gender
  auth_post "$1" "/children" "{
    \"nickname\":\"$2\",
    \"birthYear\":$3,
    \"birthMonth\":$4,
    \"gender\":\"$5\"
  }" >/dev/null
}
add_child "$TOKEN_A" "A아이1" 2022 5 "MALE"
add_child "$TOKEN_A" "A아이2" 2023 2 "FEMALE"

add_child "$TOKEN_B" "B아이1" 2022 8 "FEMALE"
add_child "$TOKEN_B" "B아이2" 2024 1 "MALE"

add_child "$TOKEN_C" "C아이1" 2021 3 "MALE"
add_child "$TOKEN_C" "C아이2" 2022 7 "FEMALE"
add_child "$TOKEN_C" "C아이3" 2023 11 "MALE"
add_child "$TOKEN_C" "C아이4" 2024 4 "FEMALE"

# ─── 4. Round 별 방 사전 생성 (모두 A 호스트) ──────────────────────────
echo ""
echo ">>> [4/7] Round 별 방 생성..."
TOMORROW=$(date -v+1d +%Y-%m-%d 2>/dev/null || date -d "+1 day" +%Y-%m-%d)

create_room_a() {
  # $1 title  $2 joinType  $3 genderFilter  $4 singleParentOnly(true/false)
  # placeName/placeAddress 는 위치 노출 단계화 검증용 — 참여 확정자에게만 공개됨.
  auth_post "$TOKEN_A" "/rooms" "{
    \"title\":\"$1\",
    \"description\":\"e2e $1 (${TS})\",
    \"placeType\":\"PLAYGROUND\",
    \"placeName\":\"역삼 어린이공원\",
    \"placeAddress\":\"서울 강남구 역삼동 123-45\",
    \"joinType\":\"$2\",
    \"genderFilter\":\"$3\",
    \"singleParentOnly\":$4,
    \"ageMonthMin\":0,
    \"ageMonthMax\":84,
    \"maxMembers\":5,
    \"date\":\"$TOMORROW\",
    \"startTime\":\"14:00\",
    \"regionSido\":\"서울특별시\",
    \"regionSigungu\":\"강남구\",
    \"regionDong\":\"역삼동\"
  }"
}

R1_RAW=$(create_room_a "e2e_R1_일반_${TS}" "FREE" "ALL" "false")
ROOM_ID_1=$(extract "$R1_RAW" 'id')
R2_RAW=$(create_room_a "e2e_R2_MOM_ONLY_${TS}" "APPROVAL" "MOM_ONLY" "false")
ROOM_ID_2=$(extract "$R2_RAW" 'id')
R3_RAW=$(create_room_a "e2e_R3_한부모_${TS}" "FREE" "ALL" "true")
ROOM_ID_3=$(extract "$R3_RAW" 'id')

if [ -z "$ROOM_ID_1$ROOM_ID_2$ROOM_ID_3" ]; then
  echo "❌ 방 생성 실패."
  echo "R1: $R1_RAW"
  echo "R2: $R2_RAW"
  echo "R3: $R3_RAW"
  exit 1
fi
echo "  room1 = $ROOM_ID_1"
echo "  room2 = $ROOM_ID_2"
echo "  room3 = $ROOM_ID_3"

# ─── 5. test_results 디렉토리 초기화 ──────────────────────────────────
echo ""
echo ">>> [5/7] $RESULTS_DIR 초기화..."
rm -rf "$RESULTS_DIR"
mkdir -p "$RESULTS_DIR"

# ─── 6. (사전 처리 단계는 A 시작 직전 동기 호출로 옮김) ────────────────
echo ""
echo ">>> [6/7] (Round1 COMPLETED 는 A 시작 직전에 동기 처리)"

# ─── 7. 세 시뮬에서 flutter drive 순차 실행 ────────────────────────────
# 동시 빌드 시 .dart_tool 캐시 race 로 모든 시뮬이 마지막 dart-define 값을
# 공유하는 문제가 있어 순차 실행. 시나리오의 시간차 의존성(B 신청 → A 승인 등)
# 도 순서 (C → B → A) 로 자연스럽게 보장됨.
echo ""
echo ">>> [7/7] flutter drive 순차 실행 (C → B → A)..."

drive_role() {
  local role="$1" device="$2" token="$3" refresh="$4" uid="$5" other1="$6" other2="$7" pg="$8" single="$9"
  TEST_RESULTS_DIR="$RESULTS_DIR" flutter drive \
    -d "$device" \
    --driver=test_driver/integration_test.dart \
    --target=integration_test/main_scenario_test.dart \
    --dart-define=TEST_API_BASE_URL="$API_URL" \
    --dart-define=API_BASE_URL="${API_URL%/v1}" \
    --dart-define=ENVIRONMENT=production \
    --dart-define=TEST_USER_ROLE="$role" \
    --dart-define=TEST_ACCESS_TOKEN="$token" \
    --dart-define=TEST_REFRESH_TOKEN="$refresh" \
    --dart-define=TEST_USER_ID="$uid" \
    --dart-define=TEST_OTHER_USER_ID_1="$other1" \
    --dart-define=TEST_OTHER_USER_ID_2="$other2" \
    --dart-define=TEST_ROOM_ID_1="$ROOM_ID_1" \
    --dart-define=TEST_ROOM_ID_2="$ROOM_ID_2" \
    --dart-define=TEST_ROOM_ID_3="$ROOM_ID_3" \
    --dart-define=TEST_PARENT_GENDER="$pg" \
    --dart-define=TEST_IS_SINGLE_PARENT="$single" 2>&1 | sed "s/^/[$role] /"
}

set +e
# C 먼저 — round1/2/3 의 reject/join 시도. 결과 DB 에 반영.
drive_role C "$SIM_DEVICE_C" "$TOKEN_C" "$REFRESH_C" "$ID_C" "$ID_A" "$ID_B" "DAD" "false"
EXIT_C=$?

# B 두번째 — round1 join + 채팅, round2 신청(승인 대기), round3 join + 채팅.
drive_role B "$SIM_DEVICE_B" "$TOKEN_B" "$REFRESH_B" "$ID_B" "$ID_A" "$ID_C" "MOM" "true"
EXIT_B=$?

# A 시작 전 round1 COMPLETED 처리 (후기 작성 위해).
ssh_psql "UPDATE room SET status='COMPLETED', completed_at=NOW() WHERE id='$ROOM_ID_1';" >/dev/null 2>&1 || true
echo "  ⚙ Round1 COMPLETED 처리됨"

# A 마지막 — 채팅, B 신청 승인, 후기 작성.
drive_role A "$SIM_DEVICE_A" "$TOKEN_A" "$REFRESH_A" "$ID_A" "$ID_B" "$ID_C" "MOM" "true"
EXIT_A=$?
set -e

echo ""
echo "=============================="
echo "  A exit=$EXIT_A   B exit=$EXIT_B   C exit=$EXIT_C"
echo "  스크린샷: $RESULTS_DIR"
ls -1 "$RESULTS_DIR" 2>/dev/null | sed 's/^/    /'
echo "  생성: users $ID_A, $ID_B, $ID_C / rooms $ROOM_ID_1, $ROOM_ID_2, $ROOM_ID_3"
echo "=============================="

if [ "$EXIT_A" != "0" ] || [ "$EXIT_B" != "0" ] || [ "$EXIT_C" != "0" ]; then
  exit 1
fi

# ─── (선택) 클린업 ──────────────────────────────────────────────────
# 운영 DB 오염 방지를 위해 끝나면 직접 지우세요. 테이블명은 entity 정의에 맞춰 조정:
#   DELETE FROM review        WHERE room_id IN ('$ROOM_ID_1','$ROOM_ID_2','$ROOM_ID_3');
#   DELETE FROM chat_message  WHERE room_id IN ('$ROOM_ID_1','$ROOM_ID_2','$ROOM_ID_3');
#   DELETE FROM room_member   WHERE room_id IN ('$ROOM_ID_1','$ROOM_ID_2','$ROOM_ID_3');
#   DELETE FROM join_request  WHERE room_id IN ('$ROOM_ID_1','$ROOM_ID_2','$ROOM_ID_3');
#   DELETE FROM room          WHERE id IN ('$ROOM_ID_1','$ROOM_ID_2','$ROOM_ID_3');
#   DELETE FROM child         WHERE user_id IN ('$ID_A','$ID_B','$ID_C');
#   DELETE FROM "user"        WHERE id IN ('$ID_A','$ID_B','$ID_C');
