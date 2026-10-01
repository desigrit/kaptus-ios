import XCTest
import CryptoKit
@testable import Kaptus

private final class ModelProtocol: URLProtocol {
    static var response: (Int, [String: String], Data) = (200, [:], Data())
    static var shouldFinish = true
    static var seenRange: String?
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "model.example.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.seenRange = request.value(forHTTPHeaderField: "Range")
        let (status, fields, data) = Self.response
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: fields)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        if Self.shouldFinish { client?.urlProtocolDidFinishLoading(self) }
    }
    override func stopLoading() {}
}
@MainActor
final class ModelDownloadTests: XCTestCase {
    private func fixture(_ root: URL, data: Data) -> SpeechModelManager {
        let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [ModelProtocol.self]
        let artifact = SpeechModelArtifact(filename: "fixture.bin", byteCount: data.count,
            digest: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(),
            url: URL(string: "https://model.example.test/fixture.bin")!)
        return SpeechModelManager(root: root, artifact: artifact, sessionConfiguration: config)
    }
    private func finish(_ manager: SpeechModelManager) async {
        for _ in 0..<100 {
            if !manager.isDownloading { return }
            try? await Task.sleep(for: .milliseconds(20))
        }
        XCTFail("Bounded fixture download did not finish")
    }
    func testVerifiedCachedArtifactIsReadyOnColdLaunchWithoutDownload() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("original verified cached model fixture".utf8)
        let path = root.appendingPathComponent("fixture.bin")
        try data.write(to: path)
        let manager = fixture(root, data: data)
        await manager.verifyExisting()
        XCTAssertTrue(manager.isReady)
        XCTAssertEqual(manager.path, path.path)
        XCTAssertFalse(manager.isDownloading)
        XCTAssertNil(manager.errorMessage)
    }
    func testVerifiedDownloadAndDelete() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("original synthetic model fixture".utf8)
        ModelProtocol.response = (200, ["Content-Length": String(data.count)], data)
        let manager = fixture(root, data: data); manager.download(); await finish(manager)
        XCTAssertTrue(manager.isReady); XCTAssertNil(manager.errorMessage); XCTAssertEqual(manager.progress, 1)
        XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: try XCTUnwrap(manager.path))), data)
        manager.delete(); XCTAssertFalse(manager.isReady)
    }
    func testRangeResumeAndIntegrityFailure() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("original resumable model fixture".utf8)
        try data.prefix(8).write(to: root.appendingPathComponent("fixture.bin.partial"))
        ModelProtocol.response = (206, ["Content-Range": "bytes 8-\(data.count - 1)/\(data.count)", "Content-Length": String(data.count - 8)], Data(data.dropFirst(8)))
        let manager = fixture(root, data: data); manager.download(); await finish(manager)
        XCTAssertEqual(ModelProtocol.seenRange, "bytes=8-"); XCTAssertTrue(manager.isReady)
        manager.delete()
        ModelProtocol.response = (200, ["Content-Length": String(data.count)], Data(repeating: 0, count: data.count))
        manager.download(); await finish(manager)
        XCTAssertFalse(manager.isReady); XCTAssertNotNil(manager.errorMessage)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("fixture.bin.partial").path))
    }
    func testCancellationKeepsBoundedPartialAndResumeCompletes() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { ModelProtocol.shouldFinish = true; try? FileManager.default.removeItem(at: root) }
        let data = Data(repeating: 7, count: 256 * 1024)
        ModelProtocol.shouldFinish = false
        ModelProtocol.response = (200, ["Content-Length": String(data.count)], Data(data.prefix(128 * 1024)))
        let manager = fixture(root, data: data); manager.download()
        let partial = root.appendingPathComponent("fixture.bin.partial")
        for _ in 0..<100 {
            if ((try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0) >= 64 * 1024 { break }
            try? await Task.sleep(for: .milliseconds(20))
        }
        manager.cancel(); await finish(manager)
        XCTAssertFalse(manager.isReady)
        let saved = (try? partial.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
        XCTAssertGreaterThanOrEqual(saved, 64 * 1024); XCTAssertLessThanOrEqual(saved, 128 * 1024)
        ModelProtocol.shouldFinish = true
        ModelProtocol.response = (206, ["Content-Range": "bytes \(saved)-\(data.count - 1)/\(data.count)", "Content-Length": String(data.count - saved)], Data(data.dropFirst(saved)))
        manager.download(); await finish(manager)
        XCTAssertTrue(manager.isReady)
    }
    func testUnexpectedResumeResponseNeverMarksReadyAndAllowsRetry() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let data = Data("synthetic model fixture for retry".utf8)
        try data.prefix(4).write(to: root.appendingPathComponent("fixture.bin.partial"))
        ModelProtocol.response = (206, ["Content-Range": "bytes 8-9/10"], Data("bad".utf8))
        let manager = fixture(root, data: data); manager.download(); await finish(manager)
        XCTAssertFalse(manager.isReady); XCTAssertNotNil(manager.errorMessage)
        // Servers may ignore Range. A fresh 200 safely replaces the partial file.
        ModelProtocol.response = (200, ["Content-Length": String(data.count)], data)
        manager.download(); await finish(manager)
        XCTAssertTrue(manager.isReady)
    }
}
