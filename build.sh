#!/bin/bash
# Builds "Water Cat.app" into ./build
set -euo pipefail
cd "$(dirname "$0")"

APP="build/Water Cat.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS"

swiftc -O -swift-version 5 -target "$(uname -m)-apple-macos13.0" \
    Sources/*.swift -o "$APP/Contents/MacOS/WaterCat"
cp Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"

echo "Built $APP"
