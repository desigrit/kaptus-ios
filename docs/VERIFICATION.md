# Verification

This is a development preview for real-device testing. It has been compiled and tested with Apple's toolchain on a macOS runner. No physical iPhone or theater test has been performed in this Windows workspace.

## Verified on September 22, 2026

[Successful final run](https://github.com/desigrit/kaptus-ios/actions/runs/35718030052), commit `9bd303f`, Xcode 26.3 (17C529), Swift 6.2.4, iPhone 17 Pro Simulator running iOS 26.2. All 35 tests passed.

An [earlier compatibility run](https://github.com/desigrit/kaptus-ios/actions/runs/35715629175) also passed its then-current 34 tests on Xcode 16.4 with iPhone 16 Pro/iOS 18.5. The final run adds the Re-sync controls-timer regression test.

| Check | Result |
| --- | --- |
| Core Swift package | 24 tests passed |
| Native iOS tests | 8 tests passed |
| SwiftUI interaction tests | 3 tests passed |
| Release build for a physical iPhone target | Compiled successfully for arm64, without signing |
| Installed-bundle inspection | Both model files present, with the expected SHA-256 digests |
| Native screenshots | Home in light/dark mode, Settings, player in portrait/landscape, largest accessibility Home |

The tests exercise SRT encodings, formatting, malformed blocks, gzip payloads, subtitle ranking, punctuation-independent matching, omitted words, duplicate dialogue, unrelated speech, bounded transcript history, clock seeks, pause/adjustment, transcription latency, and drift-estimator math. Provider contract tests use synthetic HTTP responses for search, episodes, download credentials, authentication errors, quotas, offline errors, unsafe links, and malformed responses. They do not use a live OpenSubtitles account.

Native tests load the actual bundled Whisper and Silero models, transcribe an original sentence synthesized by macOS, locate it among caption cues, and reject silence. They also exercise real simulator Keychain storage and private caption-file reopening. Lifecycle tests inject a recognition engine to check match/timeout/background microphone shutdown, manual actions, explicit resync, permission denial, and retention of visible controls when Re-sync interrupts a pending auto-hide timer.

UI tests navigate Settings, run the original sample player, adjust timing, pause, rotate, reveal and hide controls, and reach setup actions at the largest accessibility text size. A separate capture pass records actual Simulator screens, not browser mockups.

## Independent review

A separate reviewer inspected all six final native captures and confirmed the accessibility label, Re-sync controls timer, and recovery-copy corrections were resolved. The final ship disposition is scoped to those three fixes. See the [review record](REVIEW.md). The committed generated Xcode project also byte-matches the project produced in the final successful run.

## What this does not establish

- The 90% acquisition-within-30-seconds target, sub-second median accuracy, or a measured wrong-scene rate across movies.
- Performance of Metal inference, microphone routing, room speakers, noisy theaters, alternate cuts, or Bluetooth devices on a real iPhone.
- Two hours without memory growth, crashes, excessive battery use, or thermal throttling. The two-hour clock test checks anchor arithmetic, not a two-hour running app.
- Live provider authentication/download compatibility with a user's account.
- Physical signing, TestFlight distribution, App Store review, or App Store privacy approval.
- iPad layouts or Intel Simulator execution. The native framework includes an x86_64 simulator slice, but runtime tests use Apple Silicon.

The initial player follows a 1.0 playback rate and does not listen periodically after synchronization. Frame-rate or cut drift needs manual adjustment or an explicit Re-sync. The tested core drift estimator is reserved for a later player integration.

Use the [device checklist](DEVICE_TESTING.md) before relying on the preview during a movie. The synthetic integration test proves that the real recognition path is connected; its CPU Simulator duration is not an iPhone performance benchmark.
