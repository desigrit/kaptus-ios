import XCTest
import KaptusCore
@testable import Kaptus

final class ServiceTests: XCTestCase {
    func testKeychainRoundTrip() throws {
        let previous = try KeychainStore.load()
        defer { try? KeychainStore.save(previous) }
        let fixture = ProviderCredentials(apiKey: "synthetic-test-key", username: "fixture-user", password: "fixture-password")
        try KeychainStore.save(fixture)
        XCTAssertEqual(try KeychainStore.load(), fixture)
        try KeychainStore.save(.init())
        XCTAssertFalse(try KeychainStore.load().isConfigured)
    }
    func testPrivateLibraryImportsAndReopensWithoutProvider() async throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let library = CaptionLibrary(root: root)
        _ = try await library.load()
        let data = Data("1\n00:00:01,000 --> 00:00:04,000\nAn original line for offline testing.".utf8)
        let saved = try await library.save(data: data, movie: .init(id: "local-test", title: "Original fixture"), track: .init(fileID: 1, name: "fixture.srt"))
        let reopened = CaptionLibrary(root: root)
        let history = try await reopened.load()
        XCTAssertEqual(history.count, 1)
        let captions = try await reopened.open(saved)
        XCTAssertEqual(captions.first?.1.first?.text, "An original line for offline testing.")
        try await reopened.delete(saved)
        let remaining = try await reopened.load()
        XCTAssertTrue(remaining.isEmpty)
    }
}
