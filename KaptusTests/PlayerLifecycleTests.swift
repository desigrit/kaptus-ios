import XCTest
import KaptusCore
@testable import Kaptus

@MainActor
private final class TestRecognition: SpeechRecognitionEngine {
    var onState: ((SyncState) -> Void)?
    var onSegment: ((RecognizedSegment) -> Void)?
    var onFailure: (() -> Void)?
    var starts = 0
    var recording = false
    var released = false
    func start() async throws { starts += 1; recording = true; onState?(.listening) }
    func stop(releaseModel: Bool) { recording = false; released = releaseModel }
}
@MainActor
final class PlayerLifecycleTests: XCTestCase {
    private func player(_ speech: TestRecognition, allowed: Bool = true, timeout: Double = 35) -> PlayerSession {
        let cues = [CaptionCue(id: 1, start: 500, end: 506, text: "Bring the silver telescope to the old observatory.")]
        return PlayerSession(title: "Original fixture", tracks: [(.init(metadata: .init(fileID: 1, name: "Fixture"), filename: ""), cues)], speech: speech, permissionProvider: { allowed }, attemptSeconds: timeout)
    }
    private func settle() async { try? await Task.sleep(for: .milliseconds(80)) }
    func testMatchStopsMicrophoneAndManualActionsNeverRestartIt() async {
        let speech = TestRecognition()
        let session = player(speech)
        defer { session.close() }
        session.startInitial(); await settle()
        XCTAssertTrue(speech.recording)
        let tokens = "Bring the silver telescope to the old observatory".split(separator: " ").map(String.init)
        let start = MonotonicTime.now - 6
        let words = tokens.enumerated().map { index, text in
            let t = start + Double(index) * 6 / Double(tokens.count)
            return RecognizedWord(text: text, start: t, end: t + 6 / Double(tokens.count))
        }
        speech.onSegment?(.init(words: words, captureStart: start, captureEnd: start + 6))
        XCTAssertEqual(session.state, .synced)
        XCTAssertFalse(speech.recording)
        XCTAssertEqual(speech.starts, 1)
        session.seek(to: 502)
        session.adjust(by: 0.5)
        session.foregroundChanged(false, background: true)
        session.foregroundChanged(true)
        session.startInitial() // SwiftUI may re-emit onAppear after a view transition.
        XCTAssertEqual(speech.starts, 1)
        XCTAssertFalse(speech.recording)
        XCTAssertEqual(session.adjustment, 0.5)
    }
    func testBackgroundStopsAcquisitionAndOnlyExplicitResyncRestarts() async {
        let speech = TestRecognition()
        let session = player(speech)
        defer { session.close() }
        session.startInitial(); await settle()
        XCTAssertTrue(speech.recording)
        session.foregroundChanged(false, background: true)
        XCTAssertFalse(speech.recording)
        XCTAssertEqual(session.state, .interrupted)
        session.foregroundChanged(true); await settle()
        XCTAssertEqual(speech.starts, 1)
        session.resync(); await settle()
        XCTAssertEqual(speech.starts, 2)
        XCTAssertTrue(speech.recording)
        session.close()
        XCTAssertFalse(speech.recording)
        XCTAssertTrue(speech.released)
    }
    func testPermissionDenialStillAllowsManualCaptions() async {
        let speech = TestRecognition()
        let session = player(speech, allowed: false)
        defer { session.close() }
        session.startInitial(); await settle()
        XCTAssertTrue(session.microphoneDenied)
        XCTAssertEqual(speech.starts, 0)
        session.seek(to: 502); session.togglePlayback()
        XCTAssertFalse(session.activeCaption.isEmpty)
        XCTAssertEqual(speech.starts, 0)
    }
    func testTimeoutStopsMicrophone() async {
        let speech = TestRecognition()
        let session = player(speech, timeout: 0.02)
        defer { session.close() }
        session.startInitial(); await settle()
        XCTAssertEqual(speech.starts, 1)
        XCTAssertFalse(speech.recording)
        if case .needsAttention = session.state { } else { XCTFail("A timed-out attempt needs an explicit retry") }
    }
}
