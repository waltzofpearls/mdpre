#!/usr/bin/env bash
# Reproduces App Store sandbox behaviour for the mdp CLI locally.
#
#   scripts/mdp-sandbox-test.sh ./docs        # a folder
#   scripts/mdp-sandbox-test.sh ./notes.md    # a file
#
# A Debug build embeds an UNSANDBOXED mdp, because the Embed CLI Tool phase
# re-signs it on copy and drops mdp.entitlements. Bugs that only appear in the
# shipped App Store build are therefore invisible to a normal Debug run. This
# rebuilds a copy signed the way the store build is.
set -euo pipefail

TARGET=${1:?usage: mdp-sandbox-test.sh <path to open>}
ID=$(security find-identity -v -p codesigning \
       | grep -o '"Apple Development:[^"]*"' | head -1 | tr -d '"')
[ -n "$ID" ] || { echo "no Apple Development identity found"; exit 1; }

APP=$(ls -dt ~/Library/Developer/Xcode/DerivedData/MDPre-*/Build/Products/Debug/"Markdown Preview.app" 2>/dev/null | head -1)
[ -n "$APP" ] || { echo "no Debug build found, build the app first"; exit 1; }

# Must live under $HOME: the CLI's entitlement grants access relative to home.
WORK=~/Library/Caches/mdpre-sbtest
rm -rf "$WORK"; mkdir -p "$WORK"
cp -R "$APP" "$WORK/MP.app"

# Sign with the real identity, never adhoc: adhoc strips the identity the
# managed entitlements need and the app then fails to launch at all, which
# looks like the bug you are chasing but is not.
codesign --force --sign "$ID" -i dev.rollie.mdpre.mdp \
  --entitlements mdp/mdp.entitlements "$WORK/MP.app/Contents/MacOS/mdp"
codesign --force --sign "$ID" \
  --entitlements MDPre/MDPre.entitlements "$WORK/MP.app"

echo "sandboxed mdp opening: $TARGET"
"$WORK/MP.app/Contents/MacOS/mdp" "$TARGET"
echo "no error above means it opened"
