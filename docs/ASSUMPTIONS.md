# Decisions made for the iOS port

- iPhone first, iOS 17 or newer. Landscape and accessibility text sizes are supported. iPad-specific layouts are a later pass.
- Native SwiftUI, SF Symbols, Files, Keychain, and Apple navigation patterns. The established yellow Wordbird and cinema palette carry over.
- The app icon uses the same bird on an opaque teal square so iOS applies its own rounded mask. The README retains the circular Android brand badge.
- English dialogue and captions, including SDH. Movies and TV episodes are supported. Users select the title and episode; there is no movie identification from unknown audio.
- Everyone supplies their own OpenSubtitles API key, with optional account credentials. No personal key is bundled. Provider terms, account access, and quotas still apply.
- The bundled ggml-base.en-q5_1 Whisper model and Silero v6.2.0 voice activity detector provide offline recognition. These are content-pinned with SHA-256 verification. Microphone audio stays in memory.
- Initial opening and an explicit Re-sync are the only synchronization triggers. A confirmed match immediately ends capture. Manual scrubbing, timing adjustment, rotation, and returning to a synchronized player do not start the microphone.
- An anchored clock preserves elapsed movie time across app switches. iOS may suspend or terminate the process. Kaptus does not run a fake background audio session to defeat that behavior. After process termination, reopen from History and find your place again.
- This Windows workspace cannot run Xcode locally. GitHub macOS CI is the build and simulator verification path. Real room-speaker accuracy, battery use, microphone routing, and signing require a Mac and iPhone test.
- The separate repository is public, matching the Android project. This is an early development preview, not an App Store or TestFlight release. Apple signing credentials are not created or assumed.
