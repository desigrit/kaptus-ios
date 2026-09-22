#!/usr/bin/env python3
"""Fetch content-pinned dependencies. No runtime downloads or committed model blobs."""
import hashlib
import pathlib
import shutil
import sys
import tarfile
import time
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
REVISION = "927cfce34f31707e17f2bff35c349632fb9e2c3a"
ARTIFACTS = [
    ("https://github.com/ggml-org/whisper.cpp/archive/" + REVISION + ".tar.gz",
     ".build-cache/whisper.tar.gz", "41b664fee09e79176ac277b5237debec34f8d74af3c7d71f333f1ec67989ecde"),
    ("https://huggingface.co/ggerganov/whisper.cpp/resolve/main/ggml-base.en-q5_1.bin",
     "Kaptus/Resources/Models/ggml-base.en-q5_1.bin", "4baf70dd0d7c4247ba2b81fafd9c01005ac77c2f9ef064e00dcf195d0e2fdd2f"),
    ("https://huggingface.co/ggml-org/whisper-vad/resolve/main/ggml-silero-v6.2.0.bin",
     "Kaptus/Resources/Models/ggml-silero-v6.2.0.bin", "2aa269b785eeb53a82983a20501ddf7c1d9c48e33ab63a41391ac6c9f7fb6987"),
]
def sha(path):
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()

for url, relative, digest in ARTIFACTS:
    path = ROOT / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    if path.exists() and sha(path) == digest:
        print("Verified", path.name, flush=True)
        continue
    temporary = path.with_suffix(path.suffix + ".partial")
    for attempt in range(4):
        try:
            print("Fetching", path.name, flush=True)
            request = urllib.request.Request(url, headers={"User-Agent": "Kaptus-iOS-build/0.1"})
            with urllib.request.urlopen(request, timeout=120) as response, temporary.open("wb") as output:
                shutil.copyfileobj(response, output)
            if sha(temporary) != digest:
                raise RuntimeError("SHA-256 mismatch for " + path.name)
            temporary.replace(path)
            break
        except Exception:
            temporary.unlink(missing_ok=True)
            if attempt == 3:
                raise
            time.sleep(2 ** attempt)

source = ROOT / ".build-cache" / ("whisper.cpp-" + REVISION)
if not (source / "CMakeLists.txt").exists():
    with tarfile.open(ROOT / ARTIFACTS[0][1]) as archive:
        archive.extractall(ROOT / ".build-cache", filter="data")
print("Dependencies ready:", REVISION)
