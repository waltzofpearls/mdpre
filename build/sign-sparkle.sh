#!/bin/bash
set -euo pipefail

APP_BUNDLE="$1"
SIGN_IDENTITY="Developer ID Application: Ruo-Lei Ma (L2AR6TDY65)"
SPARKLE="$APP_BUNDLE/Contents/Frameworks/Sparkle.framework/Versions/B"

echo "--- Signing Sparkle framework components ---"

# Sign XPC services (inside-out)
codesign -f -s "$SIGN_IDENTITY" -o runtime "$SPARKLE/XPCServices/Installer.xpc"
codesign -f -s "$SIGN_IDENTITY" -o runtime --preserve-metadata=entitlements "$SPARKLE/XPCServices/Downloader.xpc"

# Sign other Sparkle components
codesign -f -s "$SIGN_IDENTITY" -o runtime "$SPARKLE/Autoupdate"
codesign -f -s "$SIGN_IDENTITY" -o runtime "$SPARKLE/Updater.app"

# Sign the framework itself
codesign -f -s "$SIGN_IDENTITY" -o runtime "$APP_BUNDLE/Contents/Frameworks/Sparkle.framework"

echo "--- Sparkle framework signed ---"
