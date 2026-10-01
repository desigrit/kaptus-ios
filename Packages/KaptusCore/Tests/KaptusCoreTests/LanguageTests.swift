import XCTest
@testable import KaptusCore

final class LanguageTests: XCTestCase {
    func testOfflineFallbackIncludesLessCommonLanguagesAndSeparateVariants() {
        let languages = Dictionary(uniqueKeysWithValues: CaptionLanguage.defaults.map { ($0.code, $0.name) })
        XCTAssertGreaterThanOrEqual(languages.count, 67)
        XCTAssertEqual(languages["hu"], "Hungarian")
        XCTAssertEqual(languages["cy"], "Welsh")
        XCTAssertEqual(languages["pt-br"], "Portuguese (Brazil)")
        XCTAssertEqual(languages["pt-pt"], "Portuguese (Portugal)")
        XCTAssertNotNil(languages["zh-cn"]); XCTAssertNotNil(languages["zh-tw"])
    }
    func testProductionEnablesRequestedPairsOnlyWithReadyModel() {
        for source in ["zh", "ja", "es", "fr", "de", "ko", "hi", "te", "ta"] {
            let profile = LanguageProfile(spokenLanguage: source)
            for helper in [false, true] {
                XCTAssertEqual(AutoSeekPolicy.production.capability(profile, modelReady: true, hasHelper: helper), .ready)
                XCTAssertEqual(AutoSeekPolicy.production.capability(profile, modelReady: false, hasHelper: helper), .modelRequired)
            }
            XCTAssertTrue(AutoSeekPolicy.production.allows(profile, path: .helper))
            XCTAssertTrue(AutoSeekPolicy.production.allows(profile, path: .translated))
        }
        for source in ["it", "ar", "und"] {
            for helper in [false, true] {
                let capability = AutoSeekPolicy.production.capability(.init(spokenLanguage: source), modelReady: true, hasHelper: helper)
                if case .manual = capability {} else { XCTFail("Unsupported source must remain manual") }
            }
        }
        XCTAssertEqual(AutoSeekPolicy.production.capability(.init(), modelReady: true), .ready)
        XCTAssertEqual(AutoSeekPolicy.production.capability(.init(), modelReady: false), .modelRequired)
        XCTAssertFalse(AutoSeekPolicy.production.capability(.init(captionLanguage: "ja"), modelReady: true).canListen)
        XCTAssertFalse(AutoSeekPolicy.production.allows(.init(captionLanguage: "hi", spokenLanguage: "hi"), path: .translated))
    }
    func testEvaluationIsScopedByPathAndCaptionLanguage() {
        let policy = AutoSeekPolicy(enabledPaths: ["es:helper"])
        XCTAssertEqual(policy.capability(.init(spokenLanguage: "es"), modelReady: false, hasHelper: true), .modelRequired)
        XCTAssertEqual(policy.capability(.init(spokenLanguage: "es"), modelReady: true, hasHelper: true), .ready)
        XCTAssertFalse(policy.allows(.init(spokenLanguage: "es"), path: .translated))
        XCTAssertFalse(policy.allows(.init(captionLanguage: "fr", spokenLanguage: "es"), path: .helper))
        XCTAssertFalse(AutoSeekPolicy.evaluation(languages: ["it"]).allows(.init(spokenLanguage: "it"), path: .translated))
        XCTAssertEqual(AutoSeekPolicy(enabledPaths: ["es:translated"]).capability(.init(spokenLanguage: "es"), modelReady: true, hasHelper: true), .ready)
    }
    func testNearSearchStillRejectsDistantRepeatedDialogue() {
        let text = "Bring the silver telescope to the abandoned ancient observatory"
        let matcher = SceneMatcher()
        let words = text.split(separator: " ").enumerated().map { i, word in RecognizedWord(text: String(word), start: Double(i) * 0.5, end: Double(i) * 0.5 + 0.5) }
        let segment = RecognizedSegment(words: words, captureStart: 0, captureEnd: 6)
        let duplicate = matcher.buildIndex([.init(id: 1, start: 500, end: 506, text: text), .init(id: 2, start: 1500, end: 1506, text: text)])
        XCTAssertFalse(matcher.match(segment, index: duplicate, expectedTime: 502).confident)
        let far = matcher.buildIndex([.init(id: 1, start: 500, end: 506, text: text)])
        XCTAssertNil(matcher.match(segment, index: far, expectedTime: 100).anchor)
    }
    func testRankingPreservesExactProviderVariants() {
        let movie = MovieCandidate(id: "fixture", title: "Original story")
        let tracks = [
            CaptionTrack(fileID: 1, name: "Brazil", language: "pt-br", sdh: true),
            CaptionTrack(fileID: 2, name: "Portugal", language: "pt"),
            CaptionTrack(fileID: 3, name: "English", language: "en"),
            CaptionTrack(fileID: 4, name: "Partial", language: "pt-br", foreignPartsOnly: true)
        ]
        XCTAssertEqual(TrackRanker.ranked(tracks, movie: movie, language: "pt-br").map(\.id), [1])
        XCTAssertEqual(TrackRanker.ranked(tracks, movie: movie, language: "pt").map(\.id), [2])
    }
    func testIndicCombiningMarksAndCJKCharactersSurviveNormalization() {
        XCTAssertEqual(CaptionNormalizer.tokens("நன்றி, வணக்கம்!", language: "ta"), ["நன்றி", "வணக்கம்"])
        XCTAssertEqual(CaptionNormalizer.tokens("धन्यवाद!", language: "hi"), ["धन्यवाद"])
        XCTAssertEqual(CaptionNormalizer.tokens("谢谢。", language: "zh"), ["谢", "谢"])
        XCTAssertEqual(CaptionNormalizer.tokens("ありがとう！", language: "ja").joined(), "ありがとう")
        XCTAssertEqual(CaptionNormalizer.tokens("JOHN: [Music] Where’s the telescope?"), ["wheres", "the", "telescope"])
    }
    func testUTF16ArabicAndIndicCaptionPlayback() throws {
        let text = "1\n00:00:01,000 --> 00:00:04,000\nمرحبا بالعالم\nநன்றி"
        let data = try XCTUnwrap(text.data(using: .utf16))
        XCTAssertEqual(try CaptionParser.parse(data).first?.text, "مرحبا بالعالم\nநன்றி")
    }
    func testLegacyMetadataDecodesAsEnglishDisplayWithoutLosingEpisode() throws {
        let movie = MovieCandidate(id: "8", title: "Original series", imdbID: 88, kind: .tvShow).selecting(season: 2, episode: 7)
        let item = SavedCaptions(movie: movie, tracks: [.init(metadata: .init(fileID: 1, name: "Original"), filename: "fixture.srt")])
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(item)) as? [String: Any])
        json.removeValue(forKey: "languages")
        var tracks = try XCTUnwrap(json["tracks"] as? [[String: Any]])
        tracks[0].removeValue(forKey: "role"); tracks[0].removeValue(forKey: "contentHash"); json["tracks"] = tracks
        let decoded = try JSONDecoder().decode(SavedCaptions.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.languages, .init())
        XCTAssertEqual(decoded.tracks[0].role, .display)
        XCTAssertEqual(decoded.movie.season, 2); XCTAssertEqual(decoded.movie.episode, 7)
    }
    func testMappingsAreHashBoundAndLimitedToVerifiedRegion() {
        let map = TrackTimeMapping(helperHash: "helper", displayHash: "display", offset: 17, sourceStart: 100, sourceEnd: 108)
        XCTAssertEqual(map.displayTime(for: 105), 122)
        XCTAssertNil(map.displayTime(for: 200))
    }
    func testRecognitionAccumulatorPreservesSessionTaskAndLanguage() {
        let session = UUID(), window = UUID()
        var accumulator = TranscriptAccumulator()
        let result = accumulator.append(.init(words: [.init(text: "नमस्ते", start: 2, end: 3)], captureStart: 1, captureEnd: 4, sessionID: session, language: "hi", task: .transcription, windowID: window))
        XCTAssertEqual(result.sessionID, session); XCTAssertEqual(result.windowID, window); XCTAssertEqual(result.language, "hi")
    }
    func testProviderLanguagesAndRequestedTrackLanguage() async throws {
        let catalog = HTTPResponse(data: Data(#"{"data":[{"language_code":"pt-br","language_name":"Portuguese (Brazil)"},{"language_code":"zh-tw","language_name":"Chinese (traditional)"}]}"#.utf8), status: 200)
        let empty = HTTPResponse(data: Data(#"{"data":[]}"#.utf8), status: 200)
        let transport = StubTransport([catalog, empty])
        let provider = OpenSubtitlesRepository(credentials: .init(apiKey: "synthetic-key"), transport: transport)
        let languages = try await provider.languages()
        XCTAssertEqual(Set(languages.map(\.code)), ["pt-br", "zh-tw"])
        _ = try await provider.findTracks(for: .init(id: "4", title: "Story"), language: "pt-br")
        let requests = await transport.captured()
        XCTAssertTrue(requests[0].url!.path.hasSuffix("infos/languages"))
        XCTAssertTrue(URLComponents(url: requests[1].url!, resolvingAgainstBaseURL: false)!.queryItems!.contains(.init(name: "languages", value: "pt-br")))
    }
    private func translated(_ text: String, start: Double, id: UUID = UUID()) -> RecognizedSegment {
        .init(words: text.split(separator: " ").map { .init(text: String($0), start: start, end: start + 6) },
              captureStart: start, captureEnd: start + 6, language: "en", task: .translation, windowID: id)
    }
    func testHelperRequiresEnglishCrosscheckAndMapsDifferentCutOffsets() {
        let displayText = ["Bring the silver telescope to the abandoned ancient observatory", "Leave the brass compass beside the northern entrance"]
        let sourceText = ["Trae el telescopio plateado al observatorio antiguo", "Deja la brújula dorada junto a la entrada norte"]
        let display = StoredTrack(metadata: .init(fileID: 1, name: "English"), filename: "display", contentHash: "display")
        let helper = StoredTrack(metadata: .init(fileID: 2, name: "Spanish", language: "es"), filename: "helper", role: .matchingHelper, contentHash: "helper")
        let displayCues = [CaptionCue(id: 1, start: 500, end: 501, text: displayText[0]), .init(id: 2, start: 508, end: 509, text: displayText[1])]
        let helperCues = [CaptionCue(id: 17, start: 600, end: 601, text: sourceText[0]), .init(id: 27, start: 608, end: 609, text: sourceText[1])]
        var matcher = CrossLanguageMatcher(profile: .init(spokenLanguage: "es"), policy: .evaluation(languages: ["es"]), tracks: [(display, displayCues), (helper, helperCues)])
        var result: CrossLanguageMatch?
        for i in 0..<2 {
            let id = UUID(), start = 100.0 + Double(i) * 8
            let source = RecognizedSegment(words: sourceText[i].split(separator: " ").map { .init(text: String($0), start: start + 7, end: start + 8) }, captureStart: start, captureEnd: start + 8, language: "es", windowID: id)
            XCTAssertNil(matcher.receive(source))
            let translation = RecognizedSegment(words: displayText[i].split(separator: " ").map { .init(text: String($0), start: start + 7, end: start + 8) }, captureStart: start, captureEnd: start + 8, language: "en", task: .translation, windowID: id)
            result = matcher.receive(translation)
        }
        XCTAssertEqual(result?.path, .helper)
        XCTAssertEqual(result?.mapping?.offset ?? 0, -100, accuracy: 0.5)
        XCTAssertEqual(result?.mapping?.helperHash, "helper")
        XCTAssertEqual(result?.mapping?.displayHash, "display")
    }
    func testMismatchedHelperCutFallsBackToIndependentTranslation() {
        let displayText = ["Bring the silver telescope to the abandoned ancient observatory", "Leave the brass compass beside the northern entrance"]
        let sourceText = ["Trae el telescopio plateado al observatorio antiguo", "Deja la brújula dorada junto a la entrada norte"]
        let display = StoredTrack(metadata: .init(fileID: 1, name: "English"), filename: "display", contentHash: "display")
        let helper = StoredTrack(metadata: .init(fileID: 2, name: "Spanish", language: "es"), filename: "helper", role: .matchingHelper, contentHash: "helper")
        let displayCues = [CaptionCue(id: 1, start: 500, end: 501, text: displayText[0]), .init(id: 2, start: 508, end: 509, text: displayText[1])]
        let helperCues = [CaptionCue(id: 17, start: 600, end: 601, text: sourceText[0]), .init(id: 27, start: 628, end: 629, text: sourceText[1])]
        var matcher = CrossLanguageMatcher(profile: .init(spokenLanguage: "es"), policy: .evaluation(languages: ["es"]), tracks: [(display, displayCues), (helper, helperCues)])
        var result: CrossLanguageMatch?
        for i in 0..<2 {
            let id = UUID(), start = 100.0 + Double(i) * 8
            let source = RecognizedSegment(words: sourceText[i].split(separator: " ").map { .init(text: String($0), start: start + 7, end: start + 8) }, captureStart: start, captureEnd: start + 8, language: "es", windowID: id)
            XCTAssertNil(matcher.receive(source))
            let translation = RecognizedSegment(words: displayText[i].split(separator: " ").map { .init(text: String($0), start: start + 7, end: start + 8) }, captureStart: start, captureEnd: start + 8, language: "en", task: .translation, windowID: id)
            result = matcher.receive(translation)
        }
        XCTAssertEqual(result?.path, .translated)
        XCTAssertNil(result?.mapping)
    }
    func testSilentCapturePaddingDoesNotBiasTranslatedUtteranceTime() {
        let texts = ["Bring the silver telescope to the abandoned ancient observatory", "Leave the brass compass beside the northern entrance"]
        let cues = [CaptionCue(id: 1, start: 500, end: 501, text: texts[0]), CaptionCue(id: 2, start: 508, end: 509, text: texts[1])]
        let track = StoredTrack(metadata: .init(fileID: 1, name: "Original"), filename: "display", contentHash: "display")
        var matcher = CrossLanguageMatcher(profile: .init(spokenLanguage: "es"), policy: .evaluation(languages: ["es"]), tracks: [(track, cues)])
        func padded(_ text: String, start: Double) -> RecognizedSegment {
            .init(words: text.split(separator: " ").map { .init(text: String($0), start: start + 7, end: start + 8) },
                  captureStart: start, captureEnd: start + 8, language: "en", task: .translation)
        }
        XCTAssertNil(matcher.receive(padded(texts[0], start: 100)))
        let result = matcher.receive(padded(texts[1], start: 108))
        XCTAssertEqual(result?.anchor.movieTime ?? 0, 509, accuracy: 0.5)
    }
    func testRepeatedDecodesAndOverlappingAudioDoNotConfirmTranslation() {
        let cues = [CaptionCue(id: 1, start: 500, end: 506, text: "Bring the silver telescope to the abandoned ancient observatory")]
        let track = StoredTrack(metadata: .init(fileID: 1, name: "Original"), filename: "display", contentHash: "display-hash")
        var matcher = CrossLanguageMatcher(profile: .init(spokenLanguage: "es"), policy: .evaluation(languages: ["es"]), tracks: [(track, cues)])
        let first = translated(cues[0].text, start: 100)
        XCTAssertNil(matcher.receive(first))
        XCTAssertNil(matcher.receive(first))
        XCTAssertNil(matcher.receive(translated(cues[0].text, start: 103)))
    }
    func testTranslationNeedsIndependentConsistentSceneEvidence() {
        let cues = [
            CaptionCue(id: 1, start: 500, end: 504, text: "Bring the silver telescope to the abandoned ancient observatory"),
            CaptionCue(id: 2, start: 506, end: 510, text: "Leave the brass compass beside the northern entrance")
        ]
        let track = StoredTrack(metadata: .init(fileID: 1, name: "Original"), filename: "display", contentHash: "display-hash")
        var matcher = CrossLanguageMatcher(profile: .init(spokenLanguage: "es"), policy: .evaluation(languages: ["es"]), tracks: [(track, cues)])
        XCTAssertNil(matcher.receive(translated(cues[0].text, start: 100)))
        let result = matcher.receive(translated(cues[1].text, start: 106))
        XCTAssertNotNil(result)
        XCTAssertEqual(result?.path, .translated)
        XCTAssertNil(result?.mapping)
    }
}
