#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

EC2_HOST="ubuntu@43.201.221.240"
EC2_KEY="/Users/yongju/WebProject2/kids/kids-key.pem"
REMOTE_DIR="~/kids-server"

echo "=============================="
echo "  Kids Server 배포"
echo "=============================="

# 1. 로컬 빌드
echo ""
echo ">>> [1/4] 로컬 빌드 중..."
npm run build

# 2. 서버로 전송 (로컬에서 빌드한 dist 포함, node_modules는 원격에서 설치)
echo ""
echo ">>> [2/4] 서버로 파일 전송 중..."
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude '.env' \
  --exclude 'logs' \
  -e "ssh -i $EC2_KEY -o StrictHostKeyChecking=no" \
  "$SCRIPT_DIR/" \
  "$EC2_HOST:$REMOTE_DIR/"

# 3. 원격에서 production 의존성만 설치 (nest CLI 등 dev deps 불필요 — 로컬 빌드된 dist 사용)
echo ""
echo ">>> [3/4] 원격 서버에서 production 의존성 설치 중..."
ssh -i "$EC2_KEY" "$EC2_HOST" "cd $REMOTE_DIR && npm install --production --legacy-peer-deps"

# 4. PM2 재시작
echo ""
echo ">>> [4/4] PM2 재시작 중..."
ssh -i "$EC2_KEY" "$EC2_HOST" "cd $REMOTE_DIR && pm2 restart kids-server 2>/dev/null || pm2 start dist/main.js --name kids-server && pm2 save"

echo ""
echo "=============================="
echo "  배포 완료!"
echo "  http://43.201.221.240"
echo "=============================="
