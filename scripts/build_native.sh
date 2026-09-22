#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REVISION=927cfce34f31707e17f2bff35c349632fb9e2c3a
SOURCE="$ROOT/.build-cache/whisper.cpp-$REVISION"
OUTPUT="$ROOT/Vendor"
if [ -f "$OUTPUT/whisper.xcframework/Info.plist" ] && [ "$(cat "$OUTPUT/revision.txt" 2>/dev/null)" = "$REVISION-v1" ]; then
    echo "Pinned native framework already built."
    exit 0
fi
mkdir -p "$OUTPUT/Headers"
cp "$SOURCE"/include/*.h "$OUTPUT/Headers/"
cp "$SOURCE"/ggml/include/*.h "$OUTPUT/Headers/"
for PLATFORM in iphoneos iphonesimulator; do
    ARCH=arm64
    if [ "$PLATFORM" = iphonesimulator ]; then ARCH="arm64;x86_64"; fi
    BUILD="$ROOT/.build-cache/native-$PLATFORM"
    cmake -S "$SOURCE" -B "$BUILD" -G Xcode \
        -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_SYSROOT="$PLATFORM" \
        -DCMAKE_OSX_ARCHITECTURES="$ARCH" -DCMAKE_OSX_DEPLOYMENT_TARGET=17.0 \
        -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_ALLOWED=NO \
        -DCMAKE_XCODE_ATTRIBUTE_CODE_SIGNING_REQUIRED=NO \
        -DBUILD_SHARED_LIBS=OFF -DWHISPER_BUILD_EXAMPLES=OFF \
        -DWHISPER_BUILD_TESTS=OFF -DWHISPER_BUILD_SERVER=OFF \
        -DWHISPER_COREML=OFF -DGGML_METAL=ON -DGGML_METAL_EMBED_LIBRARY=ON \
        -DGGML_BLAS=OFF -DGGML_OPENMP=OFF -DGGML_NATIVE=OFF
    cmake --build "$BUILD" --config Release --parallel 3
    mkdir -p "$OUTPUT/$PLATFORM"
    python3 "$ROOT/scripts/combine_libraries.py" "$BUILD" "$OUTPUT/$PLATFORM/libwhisper.a"
done
# Remove only this generated framework so xcodebuild can replace it.
if [ -d "$OUTPUT/whisper.xcframework" ]; then
    python3 -c 'import pathlib, shutil, sys; p=pathlib.Path(sys.argv[1]).resolve(); assert p.name=="whisper.xcframework" and p.parent.name=="Vendor"; shutil.rmtree(p)' "$OUTPUT/whisper.xcframework"
fi
xcodebuild -create-xcframework \
    -library "$OUTPUT/iphoneos/libwhisper.a" -headers "$OUTPUT/Headers" \
    -library "$OUTPUT/iphonesimulator/libwhisper.a" -headers "$OUTPUT/Headers" \
    -output "$OUTPUT/whisper.xcframework"
echo "$REVISION-v1" > "$OUTPUT/revision.txt"
