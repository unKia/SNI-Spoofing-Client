#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"

./generate_xcode_project.sh

# Prevent stale extension packaging from older builds from leaking into the new app bundle.
rm -rf "$PWD/build"

main_build_args=(
  -project SniSpoofingMac.xcodeproj
  -scheme SniSpoofingMac
  -configuration Debug
  -destination "platform=macOS,arch=arm64"
  -allowProvisioningUpdates
  -allowProvisioningDeviceRegistration
  SYMROOT="$PWD/build"
)

if [ "${ALLOW_UNSIGNED_APP_BUILD:-0}" = "1" ]; then
  echo "Unsigned app build requested. Tunnel mode run nemishe va signed app lazeme."
  main_build_args+=(CODE_SIGNING_ALLOWED=NO)
fi

xcodebuild "${main_build_args[@]}" build

xcodebuild \
  -project SniSpoofingMac.xcodeproj \
  -target SniProxyHelper \
  -configuration Debug \
  CODE_SIGNING_ALLOWED=NO \
  ARCHS=arm64 \
  ONLY_ACTIVE_ARCH=YES \
  SYMROOT="$PWD/build" \
  build
