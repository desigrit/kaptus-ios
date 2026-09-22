import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public struct HTTPResponse: Sendable {
    public let data: Data
    public let status: Int
    public init(data: Data, status: Int) { self.data = data; self.status = status }
}
public protocol HTTPTransport: Sendable {
    func send(_ request: URLRequest, maximumBytes: Int) async throws -> HTTPResponse
}
public protocol SubtitleRepository: Sendable {
    func searchMovies(_ query: String) async throws -> [MovieCandidate]
    func findTracks(for movie: MovieCandidate) async throws -> [CaptionTrack]
    func download(_ track: CaptionTrack) async throws -> Data
}

/// Ephemeral networking. Download requests never inherit provider credentials.
public final class URLSessionTransport: HTTPTransport, @unchecked Sendable {
    private let session: URLSession
    public init() {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 25
        config.timeoutIntervalForResource = 60
        config.urlCache = nil; config.httpCookieStorage = nil
        session = URLSession(configuration: config, delegate: CredentialRedirectPolicy(), delegateQueue: nil)
    }
    deinit { session.invalidateAndCancel() }
    public func send(_ request: URLRequest, maximumBytes: Int) async throws -> HTTPResponse {
        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw KaptusError.malformedResponse }
        guard response.expectedContentLength <= maximumBytes else { throw KaptusError.invalidCaptions }
        var data = Data()
        for try await byte in bytes {
            guard data.count < maximumBytes else { throw KaptusError.invalidCaptions }
            data.append(byte)
        }
        return HTTPResponse(data: data, status: http.statusCode)
    }
}
private final class CredentialRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) {
        guard request.url?.scheme == "https" else { completionHandler(nil); return }
        if task.originalRequest?.value(forHTTPHeaderField: "Api-Key") != nil,
           request.url?.host != task.originalRequest?.url?.host { completionHandler(nil); return }
        completionHandler(request)
    }
}
public actor OpenSubtitlesRepository: SubtitleRepository {
    private let credentials: ProviderCredentials
    private let transport: any HTTPTransport
    private var token: String?
    public init(credentials: ProviderCredentials, transport: any HTTPTransport = URLSessionTransport()) {
        self.credentials = credentials; self.transport = transport
    }
    private func request(_ path: String, query: [URLQueryItem] = [], body: [String: Any]? = nil, authenticate: Bool = false) async throws -> Data {
        guard credentials.isConfigured else { throw KaptusError.configuration }
        if authenticate { try await loginIfNeeded() }
        var components = URLComponents(string: "https://api.opensubtitles.com/api/v1/\(path)")!
        if !query.isEmpty { components.queryItems = query }
        var request = URLRequest(url: components.url!)
        request.setValue(credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines), forHTTPHeaderField: "Api-Key")
        request.setValue("Kaptus-iOS v0.1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpMethod = "POST"; request.httpBody = try JSONSerialization.data(withJSONObject: body)
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
        var retriedAuth = false
        for attempt in 0..<3 {
            let response: HTTPResponse
            do { response = try await transport.send(request, maximumBytes: CaptionParser.maximumBytes) }
            catch let error as URLError where [.notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost, .cannotConnectToHost].contains(error.code) { throw KaptusError.offline }
            switch response.status {
            case 200..<300: return response.data
            case 401 where authenticate && token != nil && !retriedAuth:
                token = nil; retriedAuth = true; try await loginIfNeeded()
                if let token { request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization") }
            case 401, 403, 406: throw KaptusError.authentication
            case 429: throw KaptusError.quota
            case let status where [502, 503, 504].contains(status) && attempt < 2:
                // Retry reads only. A timed-out or failed download POST can already have consumed quota.
                guard body == nil else { throw KaptusError.response(response.status) }
                try await Task.sleep(nanoseconds: UInt64(attempt + 1) * 500_000_000)
            default: throw KaptusError.response(response.status)
            }
        }
        throw KaptusError.authentication
    }
    private func loginIfNeeded() async throws {
        guard token == nil, !credentials.username.isEmpty, !credentials.password.isEmpty else { return }
        let data = try await request("login", body: ["username": credentials.username, "password": credentials.password])
        guard let value = try object(data)["token"] as? String, !value.isEmpty else { throw KaptusError.authentication }
        token = value
    }
    private func object(_ data: Data) throws -> [String: Any] {
        guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw KaptusError.malformedResponse }
        return value
    }
    private func rows(_ data: Data) throws -> [[String: Any]] {
        guard let rows = try object(data)["data"] as? [[String: Any]] else { throw KaptusError.malformedResponse }
        return rows
    }
    private func integer(_ value: Any?) -> Int? { if let n = value as? NSNumber { return n.intValue }; return (value as? String).flatMap(Int.init) }
    private func boolean(_ value: Any?) -> Bool { if let b = value as? Bool { return b }; return ["true", "1"].contains((value as? String ?? "").lowercased()) }
    public func searchMovies(_ query: String) async throws -> [MovieCandidate] {
        let query = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return [] }
        let data = try await request("features", query: [.init(name: "query", value: query)])
        var seen = Set<String>()
        return try rows(data).compactMap { row in
            guard let attrs = row["attributes"] as? [String: Any], let title = attrs["title"] as? String, !title.isEmpty else { return nil }
            let type = (attrs["feature_type"] as? String ?? "movie").lowercased()
            guard ["movie", "tvshow", "tv show", "series"].contains(type) else { return nil }
            guard let id = integer(row["id"]).map(String.init) ?? row["id"] as? String, seen.insert(id).inserted else { return nil }
            return MovieCandidate(id: id, title: title, year: integer(attrs["year"]), imdbID: integer(attrs["imdb_id"]), tmdbID: integer(attrs["tmdb_id"]), kind: type == "movie" ? .movie : .tvShow)
        }
    }
    public func findTracks(for movie: MovieCandidate) async throws -> [CaptionTrack] {
        var query: [URLQueryItem] = [.init(name: "languages", value: "en"), .init(name: "type", value: movie.kind == .episode ? "episode" : "movie")]
        let ids: [(String, Int?)] = [("imdb_id", movie.imdbID), ("tmdb_id", movie.tmdbID), ("parent_feature_id", movie.parentFeatureID), ("parent_imdb_id", movie.parentImdbID), ("parent_tmdb_id", movie.parentTmdbID), ("season_number", movie.season), ("episode_number", movie.episode)]
        query += ids.compactMap { name, value in value.map { .init(name: name, value: String($0)) } }
        if movie.kind == .movie && movie.imdbID == nil && movie.tmdbID == nil { query.append(.init(name: "query", value: movie.title)) }
        let data = try await request("subtitles", query: query)
        let tracks: [CaptionTrack] = try rows(data).compactMap { row in
            guard let attrs = row["attributes"] as? [String: Any], let files = attrs["files"] as? [[String: Any]], files.count == 1, let file = files.first, let id = integer(file["file_id"]) else { return nil }
            let rating = (attrs["ratings"] as? NSNumber)?.doubleValue ?? Double(attrs["ratings"] as? String ?? "") ?? 0
            return CaptionTrack(fileID: id, name: file["file_name"] as? String ?? "captions.srt", language: attrs["language"] as? String ?? "", sdh: boolean(attrs["hearing_impaired"]), trusted: boolean(attrs["from_trusted"]), foreignPartsOnly: boolean(attrs["foreign_parts_only"]), machineTranslated: boolean(attrs["ai_translated"]) || boolean(attrs["machine_translated"]), rating: rating, downloads: integer(attrs["download_count"]) ?? 0, release: attrs["release"] as? String ?? "")
        }
        return TrackRanker.ranked(tracks, movie: movie)
    }
    public func download(_ track: CaptionTrack) async throws -> Data {
        let data = try await request("download", body: ["file_id": track.fileID, "sub_format": "srt"], authenticate: true)
        guard let link = try object(data)["link"] as? String, let url = URL(string: link), url.scheme == "https", url.host != nil, url.user == nil, url.password == nil else { throw KaptusError.insecureDownload }
        // Separate request: never send the key or bearer token to a download host.
        let response = try await transport.send(URLRequest(url: url), maximumBytes: CaptionParser.maximumBytes)
        guard (200..<300).contains(response.status) else { throw KaptusError.response(response.status) }
        _ = try CaptionParser.parse(response.data)
        return response.data
    }
}
