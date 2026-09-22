import XCTest
@testable import KaptusCore

final class SyncTests: XCTestCase {
    private let matcher = SceneMatcher()
    private func segment(_ sentence: String, start: Double = 10, duration: Double = 6) -> RecognizedSegment {
        let tokens = sentence.split(separator: " ").map(String.init)
        return RecognizedSegment(words: tokens.enumerated().map { i, token in
            let time = start + Double(i) * duration / Double(tokens.count)
            return RecognizedWord(text: token, start: time, end: time + duration / Double(tokens.count))
        }, captureStart: start, captureEnd: start + duration)
    }
    private var cues: [CaptionCue] {
        [.init(id: 0, start: 20, end: 24, text: "The garden is waiting for rain."),
         .init(id: 1, start: 100, end: 106, text: "Bring the silver telescope to the old observatory."),
         .init(id: 2, start: 108, end: 112, text: "Meet me beside the painted wooden door."),
         .init(id: 3, start: 210, end: 214, text: "Morning light fills the empty railway station.")]
    }
    func testUniquePhraseFindsMiddleOfMovie() throws {
        let result = matcher.match(segment("Bring the silver telescope to the old observatory."), index: matcher.buildIndex(cues))
        XCTAssertTrue(result.confident)
        XCTAssertEqual(try XCTUnwrap(result.anchor).movieTime, 106, accuracy: 0.3)
    }
    func testOmissionsAndPunctuationStillMatch() {
        let result = matcher.match(segment("bring silver telescope old observatory"), index: matcher.buildIndex(cues))
        XCTAssertTrue(result.confident)
    }
    func testRepeatedDialogueIsNotConfident() {
        let repeated = cues + [.init(id: 4, start: 500, end: 506, text: cues[1].text)]
        let result = matcher.match(segment(cues[1].text), index: matcher.buildIndex(repeated))
        XCTAssertFalse(result.confident)
        XCTAssertGreaterThan(result.runnerUp, 0.9)
    }
    func testShortCommonPhraseSilenceAndWrongTrackAreRejected() {
        let index = matcher.buildIndex(cues)
        for text in ["you and me", "", "the popcorn counter closes soon tonight", "thanks for watching subscribe to the channel"] {
            XCTAssertFalse(matcher.match(segment(text), index: index).confident, text)
        }
    }
    func testTranscriptOverlapIsReplacedAndBounded() {
        var accumulator = TranscriptAccumulator()
        _ = accumulator.append(segment("one two three four five six", start: 0))
        let merged = accumulator.append(segment("four five six seven eight nine", start: 3))
        XCTAssertEqual(merged.words.map(\.text), ["one", "two", "three", "four", "five", "six", "seven", "eight", "nine"])
        for i in 0..<100 { _ = accumulator.append(segment("fresh dialogue with many different spoken words", start: Double(i * 3))) }
        let bounded = accumulator.append(segment("last window words", start: 303))
        XCTAssertLessThanOrEqual(bounded.words.count, 96)
        XCTAssertTrue(bounded.words.allSatisfy { $0.end > 291 })
    }
    func testSeekPersistsWhilePlayingAndAfterTwoHourSuspension() {
        var clock = PlaybackClock(now: 10, playing: true)
        clock.seek(to: 300, at: 20)
        XCTAssertEqual(clock.position(at: 25), 305)
        XCTAssertEqual(clock.position(at: 7220), 7500)
    }
    func testPauseAndManualAdjustmentDoNotResetClock() {
        var clock = PlaybackClock(now: 10, position: 100, playing: true)
        clock.adjust(by: 0.5)
        clock.pause(at: 20)
        XCTAssertEqual(clock.position(at: 200), 110.5)
        clock.play(at: 200)
        XCTAssertEqual(clock.position(at: 205), 115.5)
        clock.seek(to: 500, at: 205)
        XCTAssertEqual(clock.position(at: 206), 501)
    }
    func testRecognitionLatencyIsAddedToMatchedCaptureTime() {
        var clock = PlaybackClock()
        clock.align(to: .init(captureTime: 16, movieTime: 106, confidence: 1), now: 23)
        XCTAssertEqual(clock.position(at: 23), 113)
        XCTAssertEqual(clock.position(at: 24), 114)
    }
    func testFrameRateDriftNeedsLongBaselineAndIsBounded() {
        var drift = DriftEstimator()
        XCTAssertEqual(drift.add(.init(captureTime: 0, movieTime: 100, confidence: 1)), 1)
        XCTAssertEqual(drift.add(.init(captureTime: 30, movieTime: 131.25, confidence: 1)), 1)
        XCTAssertEqual(drift.add(.init(captureTime: 120, movieTime: 225, confidence: 1)), 25.0 / 24.0, accuracy: 0.001)
        var clock = PlaybackClock()
        clock.setRate(2, at: 0)
        XCTAssertEqual(clock.rate, 1.05)
    }
}
