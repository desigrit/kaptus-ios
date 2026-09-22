<p align="center">
  <img src="docs/brand/wordbird.svg" width="112" alt="Kaptus yellow Wordbird">
</p>

# Kaptus for iPhone

**Follow every line.**

A little screen for the words you don't want to miss. Kaptus puts large, quiet captions on your iPhone while a movie or TV episode plays on another screen.

Choose a title or open an SRT file. Kaptus briefly listens to the dialogue, finds your place in the captions on your phone, and switches off the microphone. The words keep moving with the story.

This is the native SwiftUI sibling of [Kaptus for Android](https://github.com/desigrit/kaptus), with the same yellow Wordbird and a distinctly iPhone experience.

## What you can do

- Open an SRT from Files, including iCloud Drive and compatible cloud storage providers.
- Find movies and TV shows through OpenSubtitles. Pick the season and episode for a show.
- Save up to three caption tracks before a night out. Prepared captions and the bundled speech models work offline.
- Read one caption at a time on a true-black screen.
- Adjust timing by half a second, pause, scrub, change text size, dim the screen, or lock its current orientation.
- Switch apps and return to the same running caption clock. Rotation keeps your session too.

The microphone runs only during an initial sync attempt or when you tap **Re-sync**. It stops after a match, when the attempt times out, or when the app leaves the foreground. Audio stays in memory and is never saved or uploaded.

## Try the preview

You need a Mac with Xcode and an iPhone running iOS 17 or newer. There is no signed IPA or TestFlight invitation yet.

```sh
git clone https://github.com/desigrit/kaptus-ios.git
cd kaptus-ios
brew install cmake xcodegen
bash scripts/bootstrap.sh
open Kaptus.xcodeproj
```

Select your Apple development team under **Signing & Capabilities**, choose your connected iPhone, and press Run. The first setup downloads and verifies the recognizer source and speech models. They are bundled into the installed app, so the phone does not download models on first launch.

Start with **Try a sample** to explore the player. Its dialogue is original demonstration text. Then open your own SRT or [set up your OpenSubtitles key](docs/OPENSUBTITLES.md).

[Device testing and troubleshooting](docs/DEVICE_TESTING.md) includes the morning test sequence. [GitHub Actions](https://github.com/desigrit/kaptus-ios/actions/workflows/ios.yml) builds the iPhone target, runs core and simulator tests, and uploads simulator artifacts. A simulator build cannot be installed on a physical iPhone.

## Your OpenSubtitles key

Each person uses their own [OpenSubtitles.com](https://www.opensubtitles.com) account and API key. Add it in Settings. An optional account login is available when your key requires authenticated downloads. Credentials are stored in this device's Keychain and are not bundled or shared.

[Follow the setup guide](docs/OPENSUBTITLES.md). Provider terms, access policies, and download limits still apply. Local SRT files work without an account.

## A few honest limits

English audio and English captions are the first supported pair. Kaptus finds a position in an existing caption file; it does not create missing captions or identify an unknown film.

A different cut, background conversation, quiet dialogue, or repeated lines can prevent a match. Tap Re-sync during a clear sentence, try another track, or set the timeline yourself. Timing is estimated from recognized words and SRT cues, so this is not a promise of frame-perfect alignment.

iOS can suspend background apps. Kaptus keeps a time anchor, so a synchronized session catches up when you return without recording in the background. If iOS terminates the app, reopen the captions from History and sync again.

Real-device speed, room-speaker accuracy, and long-session battery behavior still need hardware validation. See [verification notes](docs/VERIFICATION.md) for what has actually been checked.

## For contributors

The app uses SwiftUI, AVAudioEngine, a small application container, private caption storage, and a pinned [whisper.cpp](https://github.com/ggml-org/whisper.cpp) build with Metal on supported iPhones. The caption parser, normalization, matcher, clock, ranking, and provider contract live in a separately testable Swift package.

```sh
swift test --package-path Packages/KaptusCore
```

See [architecture](docs/ARCHITECTURE.md), [port decisions](docs/ASSUMPTIONS.md), [privacy](PRIVACY.md), and [third-party notices](THIRD_PARTY_NOTICES.md). Please keep screenshots and test fixtures free of copyrighted movie dialogue and never commit credentials.

An App Store release is planned after device testing. For now, thank you for helping Kaptus find its feet.
