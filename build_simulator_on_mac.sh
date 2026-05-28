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

xcodebuild build \
  -project LeSci.xcodeproj \
  -scheme LeSci \
  -configuration Debug \
  -destination 'platform=iOS Simulator,name=iPhone 15'
