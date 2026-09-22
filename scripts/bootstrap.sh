#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
if [ "$(uname -s)" != Darwin ]; then echo "Xcode and macOS are required for an iOS build."; exit 1; fi
for TOOL in xcodebuild cmake xcodegen python3; do
    command -v "$TOOL" >/dev/null || { echo "Missing $TOOL. See docs/DEVICE_TESTING.md."; exit 1; }
done
python3 scripts/fetch_dependencies.py
bash scripts/build_native.sh
bash scripts/prepare_test_audio.sh
echo "Ready. Open Kaptus.xcodeproj, select your Apple team, and run on an iPhone."
