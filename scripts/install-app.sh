#!/bin/zsh
set -euo pipefail

ROOT="${0:A:h:h}"
BUILT_APP="$ROOT/build/NextDNS Stats.app"
INSTALLED_APP="/Applications/NextDNS Stats.app"
REQUIREMENTS="$ROOT/Resources/NextDNSStats.requirements"

"$ROOT/scripts/build-app.sh"
pkill -x NextDNSStats 2>/dev/null || true
sleep 1
ditto "$BUILT_APP" "$INSTALLED_APP"
xattr -cr "$INSTALLED_APP"
codesign --force --deep --sign - --requirements "$REQUIREMENTS" "$INSTALLED_APP"
codesign --verify --deep --strict --requirement '=designated => identifier "io.nextdns.stats"' "$INSTALLED_APP"
open -n "$INSTALLED_APP"

print "Installed $INSTALLED_APP"
