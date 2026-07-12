#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/NextDNS Stats.app"
CONTENTS="$APP/Contents"
BIN_DIR="$(cd "$ROOT" && swift build -c release --show-bin-path)"

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$BIN_DIR/NextDNSStats" "$CONTENTS/MacOS/NextDNSStats"
codesign --force --deep --sign - "$APP"

print "Built $APP"
