#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"

APP_PATH="$PWD/build/Debug/SniSpoofingMac.app"

if [ ! -d "$APP_PATH" ]; then
  echo "Signed app bundle not found at: $APP_PATH" >&2
  echo "Run ./build_arm_debug.sh first." >&2
  exit 1
fi

if codesign -dv "$APP_PATH" 2>&1 | grep -q "Signature=adhoc"; then
  echo "Refusing to install ad-hoc signed app: $APP_PATH" >&2
  echo "Run ./build_arm_debug.sh with provisioning enabled and check signing output." >&2
  exit 1
fi

rm -rf /Applications/SniSpoofingMac.app
rsync -a --delete "$APP_PATH/" /Applications/SniSpoofingMac.app/
open /Applications/SniSpoofingMac.app
