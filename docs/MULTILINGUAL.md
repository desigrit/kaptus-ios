# Caption languages and translated auto-seek

Kaptus can download captions in the languages OpenSubtitles offers for a film or TV episode. Local SRT files also support Unicode text. Caption language and spoken language are separate choices, including dubbed audio.

## Current availability

| Spoken audio | English captions | Other caption languages |
| --- | --- | --- |
| English | Existing on-device auto-seek | Manual timing |
| Mandarin | Auto-seek with shared multilingual model | Manual timing |
| Japanese | Auto-seek with shared multilingual model | Manual timing |
| Spanish | Auto-seek with shared multilingual model | Manual timing |
| French | Auto-seek with shared multilingual model | Manual timing |
| German | Auto-seek with shared multilingual model | Manual timing |
| Korean | Auto-seek with shared multilingual model | Manual timing |
| Hindi | Auto-seek with shared multilingual model | Manual timing |
| Telugu | Auto-seek with shared multilingual model | Manual timing |
| Tamil | Auto-seek with shared multilingual model | Manual timing |
| Other or unknown | Manual timing | Manual timing |

All nine requested foreign-audio to English pairs are enabled after the shared multilingual model is downloaded and verified. English audio continues using its bundled model. No multilingual accuracy or physical-phone speed has been certified by this implementation. Existing English room-speaker performance and the new paths still need the testing described below.

## Choosing languages

Settings remembers default languages. Each saved film or episode keeps its own caption and spoken choices. When preparing a title again, its saved choices take precedence over defaults. Provider variants such as Portuguese (Brazil) and Chinese (traditional) remain separate. A language catalog is saved privately for offline use and refreshed after seven days.

The Files import asks for both languages. Choose Unknown if you are unsure. The captions remain usable with Play, Pause, the timeline and timing adjustments without microphone permission.

History separates caption-language versions. Matching helper files never appear as display tracks. Complete subtitles, SDH descriptions and trusted human-authored uploads are preferred.

## Optional model

The bundled English model is retained. The shared multilingual speech artifact is ggml-small-q5_1.bin, 190,085,487 bytes (approximately 190 MB), pinned to revision 98aa99a0a9db05ae2342309f5096248665f7cba3.

SHA-256: ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb

Settings offers an explicit download, progress, cancellation, retry and deletion. Interrupted downloads resume from a bounded partial file when the server accepts Range. Size and SHA-256 are verified before activation and again when opening the app. Model files are private and excluded from backups. The installed English model remains independent.

## Recognition and matching

The pipeline uses one native context. With a saved spoken-language helper, it runs source-language transcription followed by translation into English from the same captured audio. Without a helper, it runs translation only, avoiding an unnecessary decoding pass. A latest-only stream retains one active window and at most one pending window. No microphone audio is written to disk or sent to a network service.

When suitable source-language subtitles exist, source transcription locates a scene there. English translation independently checks the English display track. Two non-overlapping captured windows must agree before a seek is accepted. Helper and display cue numbers are never equated, and release metadata is never treated as timing proof.

Validated helper-to-display offsets are stored by both file hashes and the verified source-time region. Different cuts or inconsistent offsets fall back to English translation matching when that path is permitted. Direct translated matching also needs independent, ordered dialogue evidence and a distinct-scene runner-up margin. Opening a saved title or tapping Re-sync never downloads helper captions or consumes provider quota. New preparation shows the maximum display-plus-helper download allowance before its download action, and reuses verified cached files.

Translation uses decoded utterance intervals, not purported English word timestamps. Silence padding around a capture is not treated as dialogue. Interpolated SRT timing and cross-language paraphrases remain approximate. Test clear dialogue first and use manual timing if a match is not found.

The 35-second attempt deadline begins after permission setup and includes native model initialization, any required decodings and matching. Initial opening and explicit Re-sync are the only triggers. Success, timeout, cancellation and backgrounding stop the microphone. Scrubbing, rotation and returning from another app never start listening.

## Performance testing

Evaluate each spoken language, platform and matching path independently using held-out, native-speaker-reviewed dialogue. Use a recent ARM64 Android phone and iPhone 17 Pro. Only original or appropriately licensed test audio should be stored in a validation corpus.

The quality targets are at least 90% correct acquisition within 30 seconds, median displayed error below one second, and zero confident wrong-scene selections in the tested negative corpus. These targets are not runtime activation gates and have not yet been demonstrated for the new pairs. Record the hardware, model digest, app revision, language, dubbing/cut details and manually marked references.

Include paraphrased translations, repeated short phrases, ASR omissions, silence, music, unrelated room speech, code-switching, unavailable helpers, misleading release names, alternate cuts, subtitle offsets, seeks and 23.976/25 fps differences. Also check airplane-mode use, cancellation during initialization and decoding, memory bounds, two-hour playback and foreground microphone lifecycle.

AutoSeekPolicy explicitly enables the nine requested pairs and keeps other combinations manual. Tests can choose individual matching paths to verify helper and translation behavior independently. Readiness is checked at every listening entry point. Download completion enables Re-sync but never starts the microphone by itself; a new opening with a ready model can make the initial attempt.

## Alternatives

If the compact multilingual model is inaccurate or slow for a particular title, use manual timing while investigating the measured failure. Do not download a larger artifact without a new product decision. Source transcription plus downloadable translation packs and multilingual semantic retrieval are possible later evaluations. Cloud recognition would require separate privacy, connectivity and cost decisions.
