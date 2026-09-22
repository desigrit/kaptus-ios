import XCTest
@testable import KaptusCore

actor StubTransport: HTTPTransport {
    var responses: [HTTPResponse]
    var requests: [URLRequest] = []
    init(_ responses: [HTTPResponse]) { self.responses = responses }
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> HTTPResponse {
        requests.append(request)
        guard !responses.isEmpty else { throw URLError(.notConnectedToInternet) }
        return responses.removeFirst()
    }
    func captured() -> [URLRequest] { requests }
}
final class ProviderTests: XCTestCase {
    private func json(_ value: String, status: Int = 200) -> HTTPResponse { .init(data: Data(value.utf8), status: status) }
    func testSearchHandlesNumericStringsAndFiltersUnsupportedFeatures() async throws {
        let transport = StubTransport([json(#"{"data":[{"id":"7","attributes":{"title":"Original story","year":"2025","feature_type":"movie","imdb_id":123}},{"id":8,"attributes":{"title":"Series","year":2024,"feature_type":"tvshow"}},{"id":9,"attributes":{"title":"Episode","feature_type":"episode"}}]}"#)])
        let client = OpenSubtitlesRepository(credentials: .init(apiKey: "test-key"), transport: transport)
        let movies = try await client.searchMovies("original")
        XCTAssertEqual(movies.count, 2)
        XCTAssertEqual(movies[0].year, 2025)
        XCTAssertEqual(movies[1].kind, .tvShow)
        let requests = await transport.captured()
        XCTAssertEqual(requests[0].value(forHTTPHeaderField: "Api-Key"), "test-key")
    }
    func testEpisodeQueryUsesParentsAndSeasonNumbers() async throws {
        let transport = StubTransport([json(#"{"data":[]}"#)])
        let client = OpenSubtitlesRepository(credentials: .init(apiKey: "test"), transport: transport)
        _ = try await client.findTracks(for: MovieCandidate(id: "5", title: "Series", imdbID: 55, kind: .tvShow).selecting(season: 2, episode: 3))
        let requests = await transport.captured()
        let query = URLComponents(url: try XCTUnwrap(requests[0].url), resolvingAgainstBaseURL: false)?.queryItems ?? []
        XCTAssertTrue(query.contains(.init(name: "parent_imdb_id", value: "55")))
        XCTAssertTrue(query.contains(.init(name: "episode_number", value: "3")))
        XCTAssertTrue(query.contains(.init(name: "type", value: "episode")))
    }
    func testDownloadNeverForwardsAPIKeyToFileHost() async throws {
        let srt = "1\n00:00:01,000 --> 00:00:03,000\nOriginal synthetic caption."
        let transport = StubTransport([json(#"{"link":"https://files.example.test/caption.srt"}"#), json(srt)])
        let client = OpenSubtitlesRepository(credentials: .init(apiKey: "test-secret"), transport: transport)
        let data = try await client.download(.init(fileID: 7, name: "caption.srt"))
        XCTAssertEqual(try CaptionParser.parse(data).count, 1)
        let requests = await transport.captured()
        XCTAssertNil(requests[1].value(forHTTPHeaderField: "Api-Key"))
        XCTAssertNil(requests[1].value(forHTTPHeaderField: "Authorization"))
        XCTAssertEqual(requests[0].httpMethod, "POST")
        XCTAssertTrue(String(data: requests[0].httpBody!, encoding: .utf8)!.contains("srt"))
    }
    func testAuthenticationAndQuotaErrors() async {
        for (status, expected) in [(401, KaptusError.authentication), (403, .authentication), (429, .quota)] {
            let transport = StubTransport([json("{}", status: status)])
            let client = OpenSubtitlesRepository(credentials: .init(apiKey: "test"), transport: transport)
            do { _ = try await client.searchMovies("story"); XCTFail("Expected provider error") }
            catch { XCTAssertEqual(error as? KaptusError, expected) }
        }
    }
    func testMalformedResponseAndUnsafeDownloadAreRejected() async {
        let malformed = OpenSubtitlesRepository(credentials: .init(apiKey: "test"), transport: StubTransport([json("not JSON")]))
        do { _ = try await malformed.searchMovies("story"); XCTFail() }
        catch { XCTAssertEqual(error as? KaptusError, .malformedResponse) }
        let insecure = OpenSubtitlesRepository(credentials: .init(apiKey: "test"), transport: StubTransport([json(#"{"link":"http://files.example.test/caption.srt"}"#)]))
        do { _ = try await insecure.download(.init(fileID: 1, name: "srt")); XCTFail() }
        catch { XCTAssertEqual(error as? KaptusError, .insecureDownload) }
    }
    func testOfflineAndUnconfiguredStates() async {
        let offline = OpenSubtitlesRepository(credentials: .init(apiKey: "test"), transport: StubTransport([]))
        do { _ = try await offline.searchMovies("story"); XCTFail() }
        catch { XCTAssertEqual(error as? KaptusError, .offline) }
        let unconfigured = OpenSubtitlesRepository(credentials: .init(), transport: StubTransport([]))
        do { _ = try await unconfigured.searchMovies("story"); XCTFail() }
        catch { XCTAssertEqual(error as? KaptusError, .configuration) }
    }
    func testQuotaConsumingDownloadIsNotRetriedOnServerFailure() async {
        let transport = StubTransport([json("{}", status: 503)])
        let client = OpenSubtitlesRepository(credentials: .init(apiKey: "test"), transport: transport)
        do { _ = try await client.download(.init(fileID: 1, name: "srt")); XCTFail() } catch {}
        let requests = await transport.captured()
        XCTAssertEqual(requests.count, 1)
    }
}
