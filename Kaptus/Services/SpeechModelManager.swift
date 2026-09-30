import CryptoKit
import Combine
import Foundation
import KaptusCore

enum SpeechModelDownloadError: Error, LocalizedError {
    case response, oversized, digest, unavailable
    var errorDescription: String? {
        switch self {
        case .response: return String(localized: "The speech model download failed. Try again when you're online.")
        case .oversized: return String(localized: "The speech model download has an unexpected size.")
        case .digest: return String(localized: "The speech model could not be verified. Please download it again.")
        case .unavailable: return String(localized: "The multilingual speech model is not installed.")
        }
    }
}
struct SpeechModelArtifact: Sendable {
    let filename: String
    let byteCount: Int
    let digest: String
    let url: URL
    static let multilingual = Self(filename: "ggml-small-q5_1.bin", byteCount: 190_085_487,
        digest: "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb",
        url: URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/98aa99a0a9db05ae2342309f5096248665f7cba3/ggml-small-q5_1.bin")!)
}
@MainActor
final class SpeechModelManager: ObservableObject {
    static let filename = "ggml-small-q5_1.bin"
    static let byteCount = 190_085_487
    static let digest = "ae85e4a935d7a567bd102fe55afc16bb595bdb618e11b2fc7591bc08120411bb"
    static let remoteURL = URL(string: "https://huggingface.co/ggerganov/whisper.cpp/resolve/98aa99a0a9db05ae2342309f5096248665f7cba3/ggml-small-q5_1.bin")!
    @Published private(set) var isReady = false
    @Published private(set) var isDownloading = false
    @Published private(set) var progress: Double = 0
    @Published private(set) var errorMessage: String?
    private let root: URL
    private let artifact: SpeechModelArtifact
    private let sessionConfiguration: URLSessionConfiguration
    private var generation = UUID()
    private var task: Task<Void, Never>?
    var path: String? { isReady ? root.appendingPathComponent(artifact.filename).path : nil }
    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Kaptus/Models", isDirectory: true), artifact: SpeechModelArtifact = .multilingual, sessionConfiguration: URLSessionConfiguration = .ephemeral) {
        self.root = root; self.artifact = artifact; self.sessionConfiguration = sessionConfiguration
        // Integrity is verified once per process before a cached artifact is offered to native code.
        Task { await verifyExisting() }
    }
    func verifyExisting() async {
        guard !isDownloading else { return }
        let url = root.appendingPathComponent(artifact.filename), token = generation, spec = artifact
        let valid = await Task.detached(priority: .utility) { (try? Self.verify(url, artifact: spec)) == true }.value
        guard generation == token, !isDownloading else { return }
        isReady = valid
    }
    nonisolated static func verify(_ url: URL, artifact: SpeechModelArtifact = .multilingual) throws -> Bool {
        let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
        var hash = SHA256(); var count = 0
        while let data = try handle.read(upToCount: 128 * 1024), !data.isEmpty {
            count += data.count; guard count <= artifact.byteCount else { return false }; hash.update(data: data)
        }
        return count == artifact.byteCount && hash.finalize().map { String(format: "%02x", $0) }.joined() == artifact.digest
    }
    func download() {
        guard !isDownloading, !isReady else { return }
        generation = UUID(); isDownloading = true; errorMessage = nil
        task = Task {
            defer { isDownloading = false; task = nil }
            do { try await performDownload() }
            catch is CancellationError { }
            catch { if !Task.isCancelled { errorMessage = error.localizedDescription } }
        }
    }
    func cancel() { task?.cancel() }
    func delete() {
        guard !isDownloading else { return }
        generation = UUID()
        do {
            for name in [artifact.filename, artifact.filename + ".partial"] {
                let url = root.appendingPathComponent(name)
                if FileManager.default.fileExists(atPath: url.path) { try FileManager.default.removeItem(at: url) }
            }
            isReady = false; progress = 0; errorMessage = nil
        } catch { errorMessage = error.localizedDescription }
    }
    private func performDownload() async throws {
        let transfer = SpeechModelTransfer(), token = generation
        try await transfer.perform(root: root, artifact: artifact, configuration: sessionConfiguration) { [weak self] value in
            Task { @MainActor in if let self, self.generation == token, self.isDownloading { self.progress = value } }
        }
        try Task.checkCancellation()
        isReady = true; progress = 1
    }
}
/// URLSession streaming and bounded file I/O run away from the main executor.
private actor SpeechModelTransfer {
    func perform(root: URL, artifact: SpeechModelArtifact, configuration: URLSessionConfiguration, progress: @Sendable (Double) -> Void) async throws {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        var directory = root; var resources = URLResourceValues(); resources.isExcludedFromBackup = true; try directory.setResourceValues(resources)
        let partial = root.appendingPathComponent(artifact.filename + ".partial")
        var existing = (try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        if existing > artifact.byteCount { try FileManager.default.removeItem(at: partial); existing = 0 }
        let config = configuration; config.timeoutIntervalForResource = 3600; config.urlCache = nil; config.httpCookieStorage = nil
        let session = URLSession(configuration: config, delegate: ModelRedirectPolicy(), delegateQueue: nil)
        defer { session.invalidateAndCancel() }
        if existing < artifact.byteCount {
            var request = URLRequest(url: artifact.url)
            if existing > 0 { request.setValue("bytes=\(existing)-", forHTTPHeaderField: "Range") }
            let (bytes, response) = try await session.bytes(for: request)
            guard let http = response as? HTTPURLResponse, [200, 206].contains(http.statusCode) else { throw SpeechModelDownloadError.response }
            if http.statusCode == 206 {
                guard http.value(forHTTPHeaderField: "Content-Range")?.hasPrefix("bytes \(existing)-") == true else { throw SpeechModelDownloadError.response }
            } else { existing = 0 }
            if response.expectedContentLength > Int64(artifact.byteCount - existing) { throw SpeechModelDownloadError.oversized }
            if !FileManager.default.fileExists(atPath: partial.path) { FileManager.default.createFile(atPath: partial.path, contents: nil) }
            let handle = try FileHandle(forWritingTo: partial)
            defer { try? handle.close() }
            if existing == 0 { try handle.truncate(atOffset: 0) } else { try handle.seekToEnd() }
            var chunk = Data(); var count = existing; var lastProgress = count
            for try await byte in bytes {
                try Task.checkCancellation()
                count += 1; guard count <= artifact.byteCount else { throw SpeechModelDownloadError.oversized }
                chunk.append(byte)
                if chunk.count >= 64 * 1024 {
                    try handle.write(contentsOf: chunk); chunk.removeAll(keepingCapacity: true)
                    if count - lastProgress >= 512 * 1024 { progress(Double(count) / Double(artifact.byteCount)); lastProgress = count }
                }
            }
            if !chunk.isEmpty { try handle.write(contentsOf: chunk) }
            try handle.synchronize()
        }
        try Task.checkCancellation()
        let spec = artifact
        let valid = try await Task.detached(priority: .utility) { try SpeechModelManager.verify(partial, artifact: spec) }.value
        try Task.checkCancellation()
        guard valid else { try? FileManager.default.removeItem(at: partial); throw SpeechModelDownloadError.digest }
        let final = root.appendingPathComponent(artifact.filename)
        if FileManager.default.fileExists(atPath: final.path) { try FileManager.default.removeItem(at: final) }
        try FileManager.default.moveItem(at: partial, to: final)
        progress(1)
    }
}
private final class ModelRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        completionHandler(request.url?.scheme == "https" ? request : nil)
    }
}
