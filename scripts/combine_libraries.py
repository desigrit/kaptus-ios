import pathlib, subprocess, sys
root = pathlib.Path(sys.argv[1])
libraries = sorted(str(p) for p in root.rglob("*.a") if "Release" in str(p) and "Objects" not in str(p))
if not libraries:
    raise SystemExit("No Release static libraries found")
subprocess.run(["xcrun", "libtool", "-static", "-o", sys.argv[2], *libraries], check=True)
