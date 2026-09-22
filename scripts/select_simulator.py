"""Select the newest installed iPhone runtime instead of relying on JSON order."""
import json
import re
import sys

available = json.load(sys.stdin)["devices"]
for runtime in sorted(available, key=lambda name: tuple(map(int, re.findall(r"\d+", name))), reverse=True):
    if ".iOS-" not in runtime:
        continue
    phones = [device for device in available[runtime] if device.get("isAvailable", True) and "iPhone" in device["name"]]
    if phones:
        phone = next((device for device in phones if "Pro" in device["name"] and "Max" not in device["name"]), phones[0])
        print(f"Selected {phone['name']} ({runtime})", file=sys.stderr)
        print(phone["udid"])
        break
else:
    sys.exit("No available iPhone Simulator. Install an iOS runtime in Xcode Settings.")
