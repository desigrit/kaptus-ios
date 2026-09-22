# Privacy in Kaptus for iOS

Kaptus uses the microphone only to locate dialogue in an existing subtitle file. Audio windows and recognized words stay in memory. Kaptus does not save microphone recordings or send audio or transcripts to a server.

Listening stops after a match, on timeout, when you close the player, or when the app leaves the foreground. Only opening a caption session or pressing Re-sync starts listening. The app does not request background audio execution.

Online search and downloads contact OpenSubtitles and its HTTPS download host. OpenSubtitles receives your search, subtitle requests, API key, and optional account login. The download host does not receive credentials from Kaptus. These services can see connection information such as an IP address. Their privacy policies apply.

Credentials are stored in the device-only Keychain. SRT files and the history index live in private Application Support storage and are excluded from iCloud device backup. Text size and onboarding completion are local preferences. Delete a History item to remove its captions. Remove saved provider details in Settings and tap Done to clear the stored values.

There are no analytics, advertising SDKs, tracking identifiers, or Kaptus account servers. Documentation links open websites with their own policies.

This describes the development preview. The App Store privacy submission must reflect the final distributed app and provider configuration.
