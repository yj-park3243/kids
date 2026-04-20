#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$SCRIPT_DIR"

PLATFORM="${1:-all}"  # ios, android, all(기본)

# App Store Connect API Key (fastlane 연동)
source ios/fastlane/.env 2>/dev/null || true

# Google Play 서비스 계정 키 경로 (추후 설정)
PLAY_KEY="$SCRIPT_DIR/../etc/google-play-key.json"

# ─── 빌드번호 자동 증가 ───
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //')
VERSION_NAME=$(echo "$CURRENT_VERSION" | cut -d'+' -f1)
BUILD_NUMBER=$(echo "$CURRENT_VERSION" | cut -d'+' -f2)
NEW_BUILD_NUMBER=$((BUILD_NUMBER + 1))
sed -i '' "s/version: $CURRENT_VERSION/version: $VERSION_NAME+$NEW_BUILD_NUMBER/" pubspec.yaml

echo "=============================="
echo "  Kids App 배포 v$VERSION_NAME+$NEW_BUILD_NUMBER"
echo "  플랫폼: $PLATFORM"
echo "=============================="

# ─── iOS ───
if [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "all" ]; then
  echo ""
  echo ">>> [iOS] Flutter IPA 빌드 중..."
  flutter build ipa --release --dart-define=ENVIRONMENT=production

  IPA_PATH=$(find build/ios/ipa -name "*.ipa" | head -1)
  if [ -z "$IPA_PATH" ]; then
    echo "❌ IPA 파일을 찾을 수 없습니다"
    exit 1
  fi

  echo ">>> [iOS] TestFlight 업로드 중..."
  xcrun altool --upload-app \
    --type ios \
    --file "$IPA_PATH" \
    --apiKey "$ASC_KEY_ID" \
    --apiIssuer "$ASC_ISSUER_ID"

  echo ">>> [iOS] TestFlight 업로드 완료!"
fi

# ─── Android ───
if [ "$PLATFORM" = "android" ] || [ "$PLATFORM" = "all" ]; then
  echo ""
  echo ">>> [Android] AAB 빌드 중..."
  flutter build appbundle --release --dart-define=ENVIRONMENT=production

  AAB_PATH="build/app/outputs/bundle/release/app-release.aab"
  if [ ! -f "$AAB_PATH" ]; then
    echo "❌ AAB 파일을 찾을 수 없습니다"
    exit 1
  fi

  if [ -f "$PLAY_KEY" ]; then
    echo ">>> [Android] Google Play 업로드 중..."
    fastlane supply \
      --aab "$AAB_PATH" \
      --json_key "$PLAY_KEY" \
      --package_name "kr.kids.app" \
      --track "internal" \
      --skip_upload_metadata \
      --skip_upload_images \
      --skip_upload_screenshots \
      --skip_upload_apk

    echo ">>> [Android] Google Play 업로드 완료!"
  else
    echo ">>> [Android] Google Play 키 파일 없음 - 수동 업로드 필요"
    echo "    AAB 파일: $AAB_PATH"
  fi
fi

echo ""
echo "=============================="
echo "  배포 완료!"
echo "=============================="
