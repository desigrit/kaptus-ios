import XCTest
import AVFoundation
import KaptusCore
@testable import Kaptus

final class RecognitionTests: XCTestCase {
    func testBundledModelsTranscribeOriginalSyntheticDialogueAndRejectSilence() async throws {
        XCTAssertTrue(WhisperWorker.modelsReady)
        let fixture = try XCTUnwrap(Bundle(for: Self.self).url(forResource: "dialogue", withExtension: "wav"))
        let file = try AVAudioFile(forReading: fixture)
        XCTAssertEqual(file.processingFormat.sampleRate, 16000)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat, frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        var samples = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
        if samples.count < 96_000 { samples += Array(repeating: 0, count: 96_000 - samples.count) }
        let worker = WhisperWorker()
        try await worker.prepare()
        defer { worker.releaseModel() }
        let result = try await worker.transcribe(AudioWindow(samples: samples, start: 100, end: 100 + Double(samples.count) / 16000))
        let words = result.words.flatMap { CaptionNormalizer.tokens($0.text) }
        XCTAssertTrue(result.speechDetected)
        XCTAssertTrue(words.contains("telescope"), words.joined(separator: " "))
        XCTAssertTrue(words.contains("observatory"), words.joined(separator: " "))
        XCTAssertTrue(result.words.allSatisfy { $0.start >= 100 && $0.end <= 100 + Double(samples.count) / 16000 })
        let silent = try await worker.transcribe(AudioWindow(samples: Array(repeating: 0, count: 96_000), start: 200, end: 206))
        XCTAssertFalse(silent.speechDetected)
        XCTAssertTrue(silent.words.isEmpty)
    }
}
