# First run on your iPhone

## Before you begin

Use a Mac with full Xcode, not only Command Line Tools. This iOS project cannot be deployed from Android Studio or a Windows PC. GitHub's macOS runner can verify builds, but your own signing team is still needed to install on an iPhone.

1. Install Xcode, launch it once, and let it install its iOS platform support.
2. In Xcode Settings, add your Apple Account. A Personal Team can be used for local development; its provisioning restrictions and expiry apply.
3. Install Homebrew, then run `brew install cmake xcodegen python`.
The scripts need Python 3.12 or newer. If `python3 --version` still reports the older Apple-provided version, start a new Terminal after installing Homebrew Python.

4. Clone this repository and run `bash scripts/bootstrap.sh`.
5. Open `Kaptus.xcodeproj`. Choose the Kaptus app target, open Signing & Capabilities, and select your team. If Xcode reports the bundle identifier is unavailable, change it to a unique identifier for your own development copy.
6. Connect and trust your iPhone. Enable Developer Mode when iOS asks for it, then select the phone as the run destination.
7. Press Run. Accept microphone access only when you start your first real synchronization attempt.

Setup verifies the SHA-256 of the native source and both models. If a download fails, rerun the script. A mismatched artifact is never accepted. The native library is built for arm64 iPhones and both arm64 and x86_64 simulators.

## A useful first test, about ten minutes

1. Open **Try a sample**. Check portrait and landscape. Tap the caption to show controls, pause, change text size, and try the half-second buttons. The sample is a UI demonstration and does not activate the microphone.
2. Open a short, known English SRT using **Open SRT file**, or add your key in Settings and find a movie or TV episode you can legally play.
3. Play a clear spoken scene through room speakers. Start Kaptus while the scene is already playing. Let it hear a full sentence.
4. Check that the iOS microphone indicator disappears after **Synced**. The status should disappear after four seconds while the captions keep running.
5. Rotate the phone and switch to another app for 20 seconds. Return. The same session should be at the current time and should not start listening again.
6. Change the delay and drag the timeline. Neither action should start the microphone.
7. Seek the movie on its playback device, then press **Re-sync** in Kaptus. Check that it relocates.
8. Prepare a title while online, turn on airplane mode, reopen it from History, and sync again.
9. Leave the player and confirm the original brightness is restored.

Also try microphone denial, a phone-call interruption, silence, an incorrect caption cut, two identical phrases in different scenes, VoiceOver, and a large accessibility text size.

## What to report

Note the iPhone model, iOS version, whether it was a debug or release build, approximate time from Listening to Synced, and the direction of any timing error. Do not send microphone recordings or account keys in an issue.

A positive timing adjustment advances the caption position and shows words earlier. A negative adjustment delays them.

## Troubleshooting

- **Speech models missing:** rerun the bootstrap script and rebuild. The Models folder must be copied into the app bundle.
- **Could not start listening:** check iPhone Settings > Privacy & Security > Microphone, stop other recording apps, and press Re-sync.
- **No clear match:** play a longer sentence, reduce nearby conversation, verify the episode or cut, and try Re-sync. Music and sound effects are intentionally ignored.
- **Provider authentication:** check the API key and either enter both account fields or leave both empty. API consumers that disallow anonymous downloads require login.
- **Quota reached:** use an already saved caption track or a local SRT. Do not repeatedly retry a quota-consuming download.
- **Xcode signing:** select your own team and a unique bundle identifier. No signing certificate or Apple account is included in this repository.
