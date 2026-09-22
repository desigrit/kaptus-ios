#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p KaptusTests/Fixtures .build-cache
say -v Samantha -r 140 -o .build-cache/synthetic.aiff "Bring the silver telescope to the old observatory."
afconvert -f WAVE -d LEF32@16000 -c 1 .build-cache/synthetic.aiff KaptusTests/Fixtures/dialogue.wav
xcodegen generate
