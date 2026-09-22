# Architecture

SwiftUI provides native navigation, searchable results, episode and preparation sheets, grouped Settings, and a full-screen player. AppStore owns PlayerSession, so rotation does not recreate the clock or recognizer. Files import uses security-scoped access and NSFileCoordinator. CaptionLibrary is an actor with an atomic JSON index and private SRT files. Keychain stores credentials.

## Recognition

AVAudioEngine captures audio, converted to 16 kHz mono Float32. A six-second ring offers windows every three seconds through AsyncStream with bufferingNewest(1). One serial worker owns whisper.cpp. Native abort callbacks cancel decoding; generation identifiers discard stale results.

AVAudioTime host timestamps map to continuous monotonic time. The C++ bridge assembles subword tokens into words and preserves timestamps. Silero VAD rejects non-speech before decoding. Native code is Release-optimized in debug builds too. Physical iPhones use Metal; the simulator uses CPU inference.

The core normalizes punctuation, apostrophes, speaker labels, and sound descriptions independently of display text. An index votes for candidate positions, followed by weighted sequence matching. Common words are down-weighted, omissions are tolerated, and a distinct runner-up scene prevents ambiguous matches. Transcript history is bounded to 18 seconds and 96 words.

Initial thresholds follow the permissive Android direction: score 0.48, three content words, runner-up margin 0.05. This port also rejects median timestamp deviation over 1.75 seconds. These are initial defaults, not measured accuracy claims.

Prepared alternative tracks use the same transcript. Listening never silently consumes more download quota. Prepare for theater is the explicit route for up to three candidates.

## Time and lifecycle

A matched anchor pairs capture time with movie position. Applying it adds transcription latency before showing a caption. The clock uses mach_continuous_time, including suspension. Manual seeks replace its anchor and offsets remain additive.

A match ends recognition. There is no periodic microphone verification. Moving the timeline cancels an unfinished acquisition and never starts one. Backgrounding stops acquisition and shows a Re-sync prompt on return. A synchronized clock simply continues. Audio interruptions stop capture.

The core includes a tested drift estimator for future use, but the first iOS player uses a 1.0 playback rate after a match. One short sample cannot establish rate drift. Long-run cut or frame-rate differences require manual adjustment or another Re-sync.

## Build and tests

The fetch script contains source and model SHA-256 digests. The native build creates a static XCFramework for arm64 iPhones and arm64/x86_64 simulators, with embedded Metal shaders. Both model files are copied into the app. No recognition download happens at runtime.

project.yml is the XcodeGen source of truth. bootstrap.sh verifies dependencies and regenerates Kaptus.xcodeproj.

KaptusCore has no SwiftUI or audio-device dependency. Tests cover parsing, normalization, ranking, episode identifiers, provider failures, download credential isolation, matching, repeated phrases, transcript bounds, latency, seeks, and long clock intervals. Native integration tests use original synthetic speech generated on the macOS runner. UI tests cover Settings, player controls, rotation, hidden controls, and accessibility text size.

The sample player contains original demonstration captions. It does not activate the microphone and is not proof of synchronization quality. See VERIFICATION.md for actual results and remaining hardware checks.
