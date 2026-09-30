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
    private var loadedPath: String?
    static var modelsReady: Bool { modelPath != nil && vadPath != nil }
    private static var modelPath: String? { Bundle.main.path(forResource: "ggml-base.en-q5_1", ofType: "bin", inDirectory: "Models") }
    private static var vadPath: String? { Bundle.main.path(forResource: "ggml-silero-v6.2.0", ofType: "bin", inDirectory: "Models") }
    func prepare(configuration: RecognitionConfiguration = .init()) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            queue.async {
                do {
                    guard let model = (configuration.model == .english ? Self.modelPath : configuration.modelPath), let vad = Self.vadPath else { throw RecognitionFailure.modelUnavailable }
                    self.lock.lock()
                    if self.loadedPath != model { self.recognizer = nil; self.loadedPath = nil }
                    let existing = self.recognizer
                    self.lock.unlock()
                    if let existing { existing.resetCancellation() }
                    else {
                        let loaded = try KWRecognizer(modelPath: model, vadPath: vad)
                        self.lock.lock(); self.recognizer = loaded; self.loadedPath = model; self.lock.unlock()
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
        queue.async { self.lock.lock(); self.recognizer = nil; self.loadedPath = nil; self.lock.unlock() }
    }
    func transcribe(_ window: AudioWindow, configuration: RecognitionConfiguration = .init(), task: RecognitionTask = .transcription, windowID: UUID = UUID()) async throws -> RecognizedSegment {
        try await withCheckedThrowingContinuation { continuation in
            queue.async {
                do {
                    self.lock.lock(); let recognizer = self.recognizer; self.lock.unlock()
                    guard let recognizer else { throw RecognitionFailure.modelUnavailable }
                    let data = window.samples.withUnsafeBytes { Data($0) }
                    let result = try recognizer.transcribe(data, language: configuration.sourceLanguage, translate: task == .translation)
                    let words = result.words.map { RecognizedWord(text: $0.text, start: window.start + $0.start, end: window.start + $0.end, confidence: $0.confidence) }
                    continuation.resume(returning: RecognizedSegment(words: words, captureStart: window.start, captureEnd: window.end, speechDetected: result.speechDetected, sessionID: configuration.sessionID, language: task == .translation ? "en" : configuration.sourceLanguage, task: task, windowID: windowID))
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
    private var samples: [Float]
    private let stride: Int
    private var writeIndex = 0
    private var filled = 0
    private var sinceEmission = 0
    init(input: AVAudioFormat, continuation: AsyncStream<AudioWindow>.Continuation, multilingual: Bool = false) throws {
        guard let output = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 16000, channels: 1, interleaved: false),
              let converter = AVAudioConverter(from: input, to: output) else { throw RecognitionFailure.captureUnavailable }
        self.converter = converter; self.format = output; self.continuation = continuation
        samples = [Float](repeating: 0, count: multilingual ? 128_000 : 96_000); stride = multilingual ? 64_000 : 48_000
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
        guard filled == samples.count, sinceEmission >= stride else { return }
        sinceEmission = 0
        let ordered = Array(samples[writeIndex...]) + Array(samples[..<writeIndex])
        let end = time.isHostTimeValid ? MonotonicTime.seconds(hostTime: time.hostTime) + hostToContinuous + Double(buffer.frameLength) / buffer.format.sampleRate : MonotonicTime.now
        continuation.yield(AudioWindow(samples: ordered, start: end - Double(samples.count) / 16000, end: end))
    }
}

@MainActor
protocol SpeechRecognitionEngine: AnyObject {
    var onState: ((SyncState) -> Void)? { get set }
    var onSegment: ((RecognizedSegment) -> Void)? { get set }
    var onFailure: (() -> Void)? { get set }
    func start() async throws
    func configure(_ configuration: RecognitionConfiguration)
    func stop(releaseModel: Bool)
}
extension SpeechRecognitionEngine {
    func configure(_ configuration: RecognitionConfiguration) {}
    func stop() { stop(releaseModel: false) }
}

@MainActor
final class SpeechRecognition: SpeechRecognitionEngine {
    private let worker = WhisperWorker()
    private var engine: AVAudioEngine?
    private var streamContinuation: AsyncStream<AudioWindow>.Continuation?
    private var task: Task<Void, Never>?
    private var generation = UUID()
    private var configuration = RecognitionConfiguration()
    func configure(_ configuration: RecognitionConfiguration) { self.configuration = configuration }
    var onState: ((SyncState) -> Void)?
    var onSegment: ((RecognizedSegment) -> Void)?
    var onFailure: (() -> Void)?
    var isCapturing: Bool { engine != nil }

    func start() async throws {
        stop()
        let attempt = UUID(); generation = attempt
        let config = configuration
        onState?(.loading)
        try await worker.prepare(configuration: config)
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
            let buffer = try CaptureBuffer(input: inputFormat, continuation: continuation, multilingual: config.model == .multilingual)
            input.installTap(onBus: 0, bufferSize: 2048, format: inputFormat) { pcm, time in buffer.accept(pcm, time: time) }
            engine.prepare(); try engine.start()
            self.engine = engine
            onState?(.listening)
            task = Task { [weak self, worker] in
                for await window in stream {
                    guard let self, !Task.isCancelled, self.generation == attempt else { break }
                    self.onState?(.transcribing)
                    do {
                        let windowID = UUID()
                        // Both tasks share one model context and the same PCM, always serial.
                        for kind in config.tasks {
                            guard !Task.isCancelled, self.generation == attempt else { break }
                            let segment = try await worker.transcribe(window, configuration: config, task: kind, windowID: windowID)
                            guard !Task.isCancelled, self.generation == attempt else { break }
                            self.onSegment?(segment)
                        }
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
