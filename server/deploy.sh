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

# 2. 서버로 전송 (node_modules, dist 제외하고 소스 전송)
echo ""
echo ">>> [2/4] 서버로 파일 전송 중..."
rsync -avz --delete \
  --exclude 'node_modules' \
  --exclude 'dist' \
  --exclude '.env' \
  --exclude 'logs' \
  -e "ssh -i $EC2_KEY -o StrictHostKeyChecking=no" \
  "$SCRIPT_DIR/" \
  "$EC2_HOST:$REMOTE_DIR/"

# 3. 원격에서 빌드 + 재시작
echo ""
echo ">>> [3/4] 원격 서버에서 설치 및 빌드 중..."
ssh -i "$EC2_KEY" "$EC2_HOST" "cd $REMOTE_DIR && npm install --production && npm run build"

# 4. PM2 재시작
echo ""
echo ">>> [4/4] PM2 재시작 중..."
ssh -i "$EC2_KEY" "$EC2_HOST" "cd $REMOTE_DIR && pm2 restart kids-server 2>/dev/null || pm2 start dist/main.js --name kids-server && pm2 save"

echo ""
echo "=============================="
echo "  배포 완료!"
echo "  http://43.201.221.240"
echo "=============================="
