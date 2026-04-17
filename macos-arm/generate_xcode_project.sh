#!/bin/zsh
set -euo pipefail

cd "$(dirname "$0")"
rm -rf SniSpoofingMac.xcodeproj
xcodegen generate
