#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

EC2_HOST="ubuntu@43.201.221.240"
EC2_KEY="/Users/yongju/WebProject2/kids/kids-key.pem"
REMOTE_DIR="/var/www/admin"

echo "=============================="
echo "  Kids Admin 배포"
echo "=============================="

# 1. 의존성 설치 (필요한 경우)
if [ ! -d node_modules ]; then
  echo ">>> [0/3] 의존성 설치..."
  npm install
fi

# 2. production 빌드 (.env.production 자동 사용)
echo ""
echo ">>> [1/3] vite 빌드..."
npm run build

# 3. dist를 EC2 /var/www/admin으로 rsync (ubuntu가 항상 소유)
echo ""
echo ">>> [2/2] EC2로 전송..."
ssh -i "$EC2_KEY" -o StrictHostKeyChecking=no "$EC2_HOST" "sudo mkdir -p $REMOTE_DIR && sudo chown -R ubuntu:ubuntu $REMOTE_DIR"
rsync -avz --delete \
  -e "ssh -i $EC2_KEY -o StrictHostKeyChecking=no" \
  "$SCRIPT_DIR/dist/" \
  "$EC2_HOST:$REMOTE_DIR/"

echo ""
echo "=============================="
echo "  배포 완료!"
echo "  https://admin.growtogether.kr"
echo "=============================="
