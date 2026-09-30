# Caption languages and translated auto-seek

Kaptus can download captions in the languages OpenSubtitles offers for a film or TV episode. Local SRT files also support Unicode text. Caption language and spoken language are separate choices, including dubbed audio.

## Current availability

| Spoken audio | English captions | Other caption languages |
| --- | --- | --- |
| English | Existing on-device auto-seek | Manual timing |
| Mandarin | Manual, awaiting physical-device validation | Manual timing |
| Japanese | Manual, awaiting physical-device validation | Manual timing |
| Spanish | Manual, awaiting physical-device validation | Manual timing |
| French | Manual, awaiting physical-device validation | Manual timing |
| German | Manual, awaiting physical-device validation | Manual timing |
| Korean | Manual, awaiting physical-device validation | Manual timing |
| Hindi | Manual, awaiting physical-device validation | Manual timing |
| Telugu | Manual, awaiting physical-device validation | Manual timing |
| Tamil | Manual, awaiting physical-device validation | Manual timing |
| Other or unknown | Manual timing | Manual timing |

No multilingual accuracy or physical-phone speed has been certified by this implementation. Production policy intentionally leaves all nine new pairs manual. Installing the optional model does not change that policy. Existing English auto-seek behavior is preserved, but its wider room-speaker performance still needs the validation described below.

## Choosing languages

Settings remembers default languages. Each saved film or episode keeps its own caption and spoken choices. When preparing a title again, its saved choices take precedence over defaults. Provider variants such as Portuguese (Brazil) and Chinese (traditional) remain separate. A language catalog is saved privately for offline use and refreshed after seven days.

The Files import asks for both languages. Choose Unknown if you are unsure. The captions remain usable with Play, Pause, the timeline and timing adjustments without microphone permission.

History separates caption-language versions. Matching helper files never appear as display tracks. Complete subtitles, SDH descriptions and trusted human-authored uploads are preferred.

## Optional model

The bundled English model is retained. The shared multilingual evaluation artifact is ggml-small-q5_1.bin, 190,085,487 bytes (approximately 190 MB), pinned to revision 98aa99a0a9db05ae2342309f5096248665f7cba3.

SHA-256: ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb

Settings offers an explicit download, progress, cancellation, retry and deletion. Interrupted downloads resume from a bounded partial file when the server accepts Range. Size and SHA-256 are verified before activation and again when opening the app. Model files are private and excluded from backups. The installed English model remains independent.

## Recognition and matching

The evaluation pipeline uses one native context and serial tasks for each audio window: source-language transcription, then translation into English from the same captured audio. A latest-only stream retains one active window and at most one pending window. No microphone audio is written to disk or sent to a network service.

When suitable source-language subtitles exist, source transcription locates a scene there. English translation independently checks the English display track. Two non-overlapping captured windows must agree before a seek is accepted. Helper and display cue numbers are never equated, and release metadata is never treated as timing proof.

Validated helper-to-display offsets are stored by both file hashes and the verified source-time region. Different cuts or inconsistent offsets fall back to English translation matching when that path is permitted. Direct translated matching also needs independent, ordered dialogue evidence and a distinct-scene runner-up margin.

Translation uses decoded utterance intervals, not purported English word timestamps. Silence padding around a capture is not treated as dialogue. Interpolated SRT timing and cross-language paraphrases remain approximate, which is why device validation is mandatory.

The 35-second attempt deadline begins after permission setup and includes native model initialization, both decodings and matching. Initial opening and explicit Re-sync are the only triggers. Success, timeout, cancellation and backgrounding stop the microphone. Scrubbing, rotation and returning from another app never start listening.

## Validation gates

Evaluate each spoken language, platform and matching path independently using held-out, native-speaker-reviewed dialogue. Use a recent ARM64 Android phone and iPhone 17 Pro. Only original or appropriately licensed test audio should be stored in a validation corpus.

To activate a pair, require at least 90% correct acquisition within 30 seconds, median displayed error below one second, and zero confident wrong-scene selections in the tested negative corpus. Record the hardware, model digest, app revision, language, dubbing/cut details and manually marked references.

Include paraphrased translations, repeated short phrases, ASR omissions, silence, music, unrelated room speech, code-switching, unavailable helpers, misleading release names, alternate cuts, subtitle offsets, seeks and 23.976/25 fps differences. Also check airplane-mode use, cancellation during initialization and decoding, memory bounds, two-hour playback and foreground microphone lifecycle.

AutoSeekPolicy accepts an explicit evaluation policy for native tests and controlled evaluation builds. It has no user-facing switch that quietly enables unvalidated language pairs. Production validation entries must be accompanied by reviewed evidence for the exact language and path.

## Alternatives

If the compact multilingual model does not meet these gates, keep that pair manual. Do not download a larger artifact without a new product decision. Source transcription plus downloadable translation packs and multilingual semantic retrieval are possible later evaluations. Cloud recognition would require separate privacy, connectivity and cost decisions.
