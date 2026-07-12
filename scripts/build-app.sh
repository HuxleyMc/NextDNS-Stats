#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
APP="$ROOT/build/NextDNS Stats.app"
CONTENTS="$APP/Contents"
BIN_DIR="$(cd "$ROOT" && swift build -c release --show-bin-path)"
REQUIREMENTS="$ROOT/Resources/NextDNSStats.requirements"

cd "$ROOT"
swift build -c release
rm -rf "$APP"
mkdir -p "$CONTENTS/MacOS" "$CONTENTS/Resources"
cp "$ROOT/Resources/Info.plist" "$CONTENTS/Info.plist"
cp "$BIN_DIR/NextDNSStats" "$CONTENTS/MacOS/NextDNSStats"
codesign --force --deep --sign - --requirements "$REQUIREMENTS" "$APP"
codesign --verify --deep --strict --requirement '=designated => identifier "io.nextdns.stats"' "$APP"

print "Built $APP"
