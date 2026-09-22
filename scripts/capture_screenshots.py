import json, pathlib, subprocess, sys, time
device = sys.argv[1]
root = pathlib.Path(__file__).resolve().parents[1]
output = root / "artifacts" / "screenshots"
output.mkdir(parents=True, exist_ok=True)
def sim(*args):
    subprocess.run(["xcrun", "simctl", *args], check=True)
def capture(name, args):
    subprocess.run(["xcrun", "simctl", "terminate", device, "com.desigrit.kaptus"], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    sim("launch", device, "com.desigrit.kaptus", "-ui-testing", *args)
    time.sleep(3)
    sim("io", device, "screenshot", str(output / name))
sim("status_bar", device, "override", "--time", "9:41", "--dataNetwork", "wifi", "--wifiMode", "active", "--wifiBars", "3", "--batteryState", "charged", "--batteryLevel", "100")
sim("ui", device, "appearance", "light")
capture("home-light.png", [])
capture("settings-light.png", ["-demo-settings"])
sim("ui", device, "appearance", "dark")
capture("home-dark.png", [])
capture("player-portrait.png", ["-demo-player"])
sim("ui", device, "content_size", "accessibility-extra-extra-extra-large")
capture("home-accessibility.png", [])
sim("ui", device, "content_size", "large")
print("Saved real iOS Simulator captures to", output)
