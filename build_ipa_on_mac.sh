#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen 未安装，正在通过 Homebrew 安装..."
  brew install xcodegen
fi

if [ ! -d "LeSci.xcodeproj" ]; then
  xcodegen generate
fi

if [ -z "${TEAM_ID:-}" ]; then
  echo "请先设置 Apple 开发者 Team ID，例如："
  echo "TEAM_ID=XXXXXXXXXX ./build_ipa_on_mac.sh"
  exit 1
fi

rm -rf build

xcodebuild archive \
  -project LeSci.xcodeproj \
  -scheme LeSci \
  -configuration Release \
  -archivePath build/LeSci.xcarchive \
  -destination generic/platform=iOS \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_STYLE=Automatic \
  -allowProvisioningUpdates

xcodebuild -exportArchive \
  -archivePath build/LeSci.xcarchive \
  -exportPath build/export \
  -exportOptionsPlist ExportOptions.plist \
  -allowProvisioningUpdates

echo "打包完成：build/export/LeSci.ipa"
