import XCTest
import KaptusCore
@testable import Kaptus

@MainActor
private final class LanguageRecognition: SpeechRecognitionEngine {
    var onState: ((SyncState) -> Void)?
    var onSegment: ((RecognizedSegment) -> Void)?
    var onFailure: (() -> Void)?
    var starts = 0
    var stops = 0
    var configuration: RecognitionConfiguration?
    func configure(_ configuration: RecognitionConfiguration) { self.configuration = configuration }
    func start() async throws { starts += 1; onState?(.listening) }
    func stop(releaseModel: Bool) { stops += 1 }
}
@MainActor
final class MultilingualTests: XCTestCase {
    func testEveryUnvalidatedPairStaysManualWithoutAskingPermissionOrLoadingModel() async {
        for spoken in ["zh", "ja", "es", "fr", "de", "ko", "hi", "te", "ta", "und"] {
            let speech = LanguageRecognition(); var permissionRequests = 0
            let session = PlayerSession(title: "Original", tracks: [
                (.init(metadata: .init(fileID: 1, name: "Original"), filename: ""), [.init(id: 1, start: 100, end: 200, text: "Original synthetic caption")])
            ], speech: speech, permissionProvider: { permissionRequests += 1; return true }, languages: .init(spokenLanguage: spoken), multilingualModelPath: "/unused")
            session.startInitial(); session.resync()
            try? await Task.sleep(for: .milliseconds(20))
            XCTAssertEqual(session.state, .manual); XCTAssertEqual(speech.starts, 0); XCTAssertNil(speech.configuration)
            XCTAssertEqual(permissionRequests, 0)
            session.seek(to: 110); session.togglePlayback()
            XCTAssertFalse(session.activeCaption.isEmpty)
            session.close()
        }
    }
    func testStaleRecognitionDoesNotMoveEnglishClock() async {
        let speech = LanguageRecognition()
        let session = PlayerSession(title: "Original", tracks: [
            (.init(metadata: .init(fileID: 1, name: "Original"), filename: ""), [.init(id: 1, start: 100, end: 106, text: "Bring the silver telescope to the old observatory")])
        ], speech: speech, permissionProvider: { true })
        defer { session.close() }
        session.startInitial(); try? await Task.sleep(for: .milliseconds(30))
        speech.onSegment?(.init(words: "Bring the silver telescope to the old observatory".split(separator: " ").map { .init(text: String($0), start: 0, end: 6) }, captureStart: 0, captureEnd: 6, sessionID: UUID()))
        XCTAssertNotEqual(session.state, .synced)
        XCTAssertEqual(session.position, 0)
    }
    func testLibraryIsolatesDisplayLanguagesAndHelperRoles() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = CaptionLibrary(root: root); _ = try await library.load()
        let movie = MovieCandidate(id: "8", title: "Series", kind: .tvShow).selecting(season: 2, episode: 3)
        let srt = Data("1\n00:00:01,000 --> 00:00:04,000\nOriginal synthetic words.".utf8)
        _ = try await library.save(data: srt, movie: movie, track: .init(fileID: 1, name: "English"), languages: .init(spokenLanguage: "es"))
        let english = try await library.save(data: srt, movie: movie, track: .init(fileID: 2, name: "Spanish helper", language: "es"), languages: .init(spokenLanguage: "es"), role: .matchingHelper)
        let japanese = try await library.save(data: srt, movie: movie, track: .init(fileID: 3, name: "Japanese", language: "ja"), languages: .init(captionLanguage: "ja", spokenLanguage: "ja"))
        let history = try await library.load(); XCTAssertEqual(history.count, 2)
        let englishTracks = try await library.open(english)
        XCTAssertEqual(englishTracks.filter { $0.0.role == .display }.map { $0.0.metadata.language }, ["en"])
        XCTAssertEqual(englishTracks.filter { $0.0.role == .matchingHelper }.map { $0.0.metadata.language }, ["es"])
        XCTAssertNotNil(englishTracks[0].0.contentHash)
        let japaneseTracks = try await library.open(japanese)
        XCTAssertEqual(japaneseTracks.map { $0.0.metadata.language }, ["ja"])
        XCTAssertEqual(japanese.movie.episode, 3)
    }
    func testMappingCacheRejectsWrongHashesAndCrossRoleDataIsReused() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = CaptionLibrary(root: root); _ = try await library.load()
        let data = Data("1\n00:00:01,000 --> 00:00:04,000\nOriginal cache fixture.".utf8)
        let track = CaptionTrack(fileID: 7, name: "Spanish", language: "es")
        let movie = MovieCandidate(id: "7", title: "Original")
        _ = try await library.save(data: data, movie: movie, track: track, languages: .init(spokenLanguage: "es"), role: .matchingHelper)
        let cached = await library.cachedData(for: track)
        XCTAssertEqual(cached, data)
        let saved = try await library.save(data: try XCTUnwrap(cached), movie: movie, track: track, languages: .init(captionLanguage: "es", spokenLanguage: "es"), role: .display)
        let opened = try await library.open(saved)
        XCTAssertEqual(opened[0].0.role, .display)
        let map = TrackTimeMapping(helperHash: "source", displayHash: "english", offset: -20, sourceStart: 100, sourceEnd: 110)
        try await library.saveMapping(map)
        let correct = await library.mappings(helperHash: "source", displayHash: "english")
        let wrongSource = await library.mappings(helperHash: "different", displayHash: "english")
        let wrongDisplay = await library.mappings(helperHash: "source", displayHash: "different")
        XCTAssertEqual(correct.count, 1); XCTAssertTrue(wrongSource.isEmpty); XCTAssertTrue(wrongDisplay.isEmpty)
    }
    func testCorruptDownloadedModelNeverBecomesReady() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let model = root.appendingPathComponent(SpeechModelManager.filename)
        try Data("invalid model".utf8).write(to: model)
        XCTAssertFalse(try SpeechModelManager.verify(model))
        let manager = SpeechModelManager(root: root)
        await manager.verifyExisting()
        XCTAssertFalse(manager.isReady)
        XCTAssertNil(manager.path)
        manager.delete()
        XCTAssertFalse(FileManager.default.fileExists(atPath: model.path))
    }
}
