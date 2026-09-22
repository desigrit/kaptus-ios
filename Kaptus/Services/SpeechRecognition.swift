import AVFoundation
import Darwin
import Foundation
import KaptusCore

struct AudioWindow: Sendable {
    let samples: [Float]
    let start: Double
    let end: Double
}
enum RecognitionFailure: Error { case modelUnavailable, captureUnavailable, decoding }

/// One worker, one newest pending window. Neither audio nor transcripts are written to disk.
final class WhisperWorker: @unchecked Sendable {
    private let queue = DispatchQueue(label: "com.desigrit.kaptus.whisper", qos: .userInitiated)
    private let lock = NSLock()
    private var recognizer: KWRecognizer?
    static var modelsReady: Bool { modelPath != nil && vadPath != nil }
    private static var modelPath: String? { Bundle.main.path(forResource: "ggml-base.en-q5_1", ofType: "bin", inDirectory: "Models") }
    private static var vadPath: String? { Bundle.main.path(forResource: "ggml-silero-v6.2.0", ofType: "bin", inDirectory: "Models") }
    func prepare() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    guard let model = Self.modelPath, let vad = Self.vadPath else { throw RecognitionFailure.modelUnavailable }
                    self.lock.lock(); let existing = self.recognizer; self.lock.unlock()
                    if let existing { existing.resetCancellation() }
                    else {
                        let loaded = try KWRecognizer(modelPath: model, vadPath: vad)
                        self.lock.lock(); self.recognizer = loaded; self.lock.unlock()
                    }
                    continuation.resume()
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
    func cancel() {
        lock.lock(); let current = recognizer; lock.unlock()
        current?.cancel()
    }
    func releaseModel() {
        cancel()
        queue.async { self.lock.lock(); self.recognizer = nil; self.lock.unlock() }
    }
    func transcribe(_ window: AudioWindow) async throws -> RecognizedSegment {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    self.lock.lock(); let recognizer = self.recognizer; self.lock.unlock()
                    guard let recognizer else { throw RecognitionFailure.modelUnavailable }
                    let data = window.samples.withUnsafeBytes { Data($0) }
                    let result = try recognizer.transcribe(data)
                    let words = result.words.map { RecognizedWord(text: $0.text, start: window.start + $0.start, end: window.start + $0.end, confidence: $0.confidence) }
                    continuation.resume(returning: RecognizedSegment(words: words, captureStart: window.start, captureEnd: window.end, speechDetected: result.speechDetected))
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}

/// Runs only on the audio tap's serial callback. Storage is bounded to six seconds.
private final class CaptureBuffer: @unchecked Sendable {
    let converter: AVAudioConverter
    let format: AVAudioFormat
    let continuation: AsyncStream<AudioWindow>.Continuation
    let hostToContinuous: Double
    private var samples = [Float](repeating: 0, count: 96_000)
    private var writeIndex = 0
    private var filled = 0
    private var sinceEmission = 0
    init(input: AVAudioFormat, continuation: AsyncStream<AudioWindow>.Continuation) throws {
        guard let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: input, to: output) else { throw RecognitionFailure.captureUnavailable }
        self.converter = converter; self.format = output; self.continuation = continuation
        hostToContinuous = MonotonicTime.now - MonotonicTime.seconds(hostTime: mach_absolute_time())
    }
    func accept(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        let capacity = AVAudioFrameCount(ceil(Double(buffer.frameLength) * 16000 / buffer.format.sampleRate)) + 64
        guard let converted = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: capacity) else { return }
        var supplied = false
        var conversionError: NSError?
        converter.convert(to: converted, error: &conversionError) { _, status in
            if supplied { status.pointee = .noDataNow; return nil }
            supplied = true; status.pointee = .haveData; return buffer
        }
        guard conversionError == nil, let pcm = converted.floatChannelData?[0], converted.frameLength > 0 else { return }
        for i in 0..<Int(converted.frameLength) {
            samples[writeIndex] = pcm[i]; writeIndex = (writeIndex + 1) % samples.count
        }
        filled = min(samples.count, filled + Int(converted.frameLength))
        sinceEmission += Int(converted.frameLength)
        guard filled == samples.count, sinceEmission >= 48_000 else { return }
        sinceEmission = 0
        let ordered = Array(samples[writeIndex...]) + Array(samples[..<writeIndex])
        let end = time.isHostTimeValid ? MonotonicTime.seconds(hostTime: time.hostTime) + hostToContinuous + Double(buffer.frameLength) / buffer.format.sampleRate : MonotonicTime.now
        continuation.yield(AudioWindow(samples: ordered, start: end - 6, end: end))
    }
}

@MainActor
protocol SpeechRecognitionEngine: AnyObject {
    var onState: ((SyncState) -> Void)? { get set }
    var onSegment: ((RecognizedSegment) -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }
    func start() async throws
    func stop(releaseModel: Bool)
}
extension SpeechRecognitionEngine {
    func stop() { stop(releaseModel: false) }
}

@MainActor
final class SpeechRecognition: SpeechRecognitionEngine {
    private let worker = WhisperWorker()
    private var engine: AVAudioEngine?
    private var streamContinuation: AsyncStream<AudioWindow>.Continuation?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    var onState: ((SyncState) -> Void)?
    var onSegment: ((RecognizedSegment) -> Void)?
    var onFailure: (() -> Void)?
    var isCapturing: Bool { engine != nil }

    func start() async throws {
        stop()
        let attempt = UUID(); generation = attempt
        onState?(.loading)
        try await worker.prepare()
        try Task.checkCancellation()
        guard generation == attempt else { return }
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playAndRecord, mode: .measurement, options: [.mixWithOthers, .defaultToSpeaker])
        try session.setPreferredSampleRate(16000)
        try session.setActive(true)
        let engine = AVAudioEngine()
        do {
            let input = engine.inputNode
            let inputFormat = input.outputFormat(forBus: 0)
            guard inputFormat.sampleRate > 0, inputFormat.channelCount > 0 else { throw RecognitionFailure.captureUnavailable }
            let (stream, continuation) = AsyncStream<AudioWindow>.makeStream(bufferingPolicy: .bufferingNewest(1))
            streamContinuation = continuation
            let buffer = try CaptureBuffer(input: inputFormat, continuation: continuation)
            input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { pcm, time in buffer.accept(pcm, time: time) }
            engine.prepare(); try engine.start()
            self.engine = engine
            onState?(.listening)
            task = Task { [weak self, worker] in
                for await window in stream {
                    guard let self, !Task.isCancelled, self.generation == attempt else { break }
                    self.onState?(.transcribing)
                    do {
                        let segment = try await worker.transcribe(window)
                        guard !Task.isCancelled, self.generation == attempt else { break }
                        self.onSegment?(segment)
                    } catch {
                        guard !Task.isCancelled, self.generation == attempt else { break }
                        self.stop(); self.onFailure?(); break
                    }
                }
            }
        } catch {
            engine.inputNode.removeTap(onBus: 0)
            try? session.setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }
    func stop(releaseModel: Bool = false) {
        generation = UUID()
        if let engine { engine.inputNode.removeTap(onBus: 0); engine.stop() }
        engine = nil; streamContinuation?.finish(); streamContinuation = nil
        task?.cancel(); task = nil; worker.cancel()
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        if releaseModel { worker.releaseModel() }
    }
}
