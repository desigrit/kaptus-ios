import hashlib, json, pathlib, plistlib, subprocess, sys
bundle = pathlib.Path(sys.argv[1])
with (bundle / "Info.plist").open("rb") as source:
    info = plistlib.load(source)
expected = {
    "ggml-base.en-q5_1.bin": "4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f",
    "ggml-silero-v6.2.0.bin": "2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987",
}
models = {}
for name, digest in expected.items():
    file = bundle / "Models" / name
    with file.open("rb") as source:
        actual = hashlib.file_digest(source, "sha256").hexdigest()
    assert actual == digest, name + " missing or changed in the installed bundle"
    models[name] = {"sha256": actual, "bytes": file.stat().st_size}
assert info.get("NSMicrophoneUsageDescription")
assert not info.get("UIBackgroundModes"), "The app must not request background recording"
assert (bundle / "PrivacyInfo.xcprivacy").is_file()
assert (bundle / "Assets.car").is_file()
architecture = subprocess.check_output(["xcrun", "lipo", "-archs", str(bundle / info["CFBundleExecutable"])], text=True).strip()
assert "arm64" in architecture
report = {"bundle": bundle.name, "architecture": architecture, "models": models, "backgroundModes": [], "microphoneUsageDescription": True, "privacyManifest": True}
pathlib.Path("artifacts").mkdir(exist_ok=True)
pathlib.Path("artifacts/bundle-verification.json").write_text(json.dumps(report, indent=2))
print(json.dumps(report, indent=2))
