import Foundation

public struct CaptionCue: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let start: Double
    public let end: Double
    public let text: String
    public init(id: Int, start: Double, end: Double, text: String) {
        self.id = id; self.start = start; self.end = end; self.text = text
    }
}

public enum MediaKind: String, Codable, Sendable { case movie, tvShow, episode }
public struct MovieCandidate: Codable, Hashable, Sendable, Identifiable {
    public let id: String
    public let title: String
    public let year: Int?
    public let imdbID: Int?
    public let tmdbID: Int?
    public let kind: MediaKind
    public var parentFeatureID: Int?
    public var parentImdbID: Int?
    public var parentTmdbID: Int?
    public var season: Int?
    public var episode: Int?
    public init(id: String, title: String, year: Int? = nil, imdbID: Int? = nil, tmdbID: Int? = nil, kind: MediaKind = .movie) {
        self.id = id; self.title = title; self.year = year; self.imdbID = imdbID; self.tmdbID = tmdbID; self.kind = kind
    }
    public func selecting(season: Int, episode: Int) -> Self {
        var item = Self(id: "\(id)-s\(season)e\(episode)", title: "\(title) · S\(String(format: "%02d", season))E\(String(format: "%02d", episode))", year: year, kind: .episode)
        item.parentFeatureID = Int(id); item.parentImdbID = imdbID; item.parentTmdbID = tmdbID
        item.season = season; item.episode = episode
        return item
    }
}

public struct CaptionTrack: Codable, Hashable, Sendable, Identifiable {
    public var id: Int { fileID }
    public let fileID: Int
    public let name: String
    public let language: String
    public let sdh: Bool
    public let trusted: Bool
    public let foreignPartsOnly: Bool
    public let machineTranslated: Bool
    public let rating: Double
    public let downloads: Int
    public let release: String
    public init(fileID: Int, name: String, language: String = "en", sdh: Bool = false, trusted: Bool = false, foreignPartsOnly: Bool = false, machineTranslated: Bool = false, rating: Double = 0, downloads: Int = 0, release: String = "") {
        self.fileID = fileID; self.name = name; self.language = language; self.sdh = sdh; self.trusted = trusted
        self.foreignPartsOnly = foreignPartsOnly; self.machineTranslated = machineTranslated
        self.rating = rating; self.downloads = downloads; self.release = release
    }
}
public struct SavedCaptions: Codable, Identifiable, Hashable, Sendable {
    public let id: UUID
    public let movie: MovieCandidate
    public var tracks: [StoredTrack]
    public var lastOpened: Date
    public init(id: UUID = UUID(), movie: MovieCandidate, tracks: [StoredTrack], lastOpened: Date = Date()) {
        self.id = id; self.movie = movie; self.tracks = tracks; self.lastOpened = lastOpened
    }
}
public struct StoredTrack: Codable, Hashable, Sendable {
    public let metadata: CaptionTrack
    public let filename: String
    public init(metadata: CaptionTrack, filename: String) { self.metadata = metadata; self.filename = filename }
}
public struct RecognizedWord: Sendable, Equatable {
    public let text: String
    public let start: Double
    public let end: Double
    public let confidence: Double
    public init(text: String, start: Double, end: Double, confidence: Double = 1) {
        self.text = text; self.start = start; self.end = end; self.confidence = confidence
    }
}
public struct RecognizedSegment: Sendable {
    public let words: [RecognizedWord]
    public let captureStart: Double
    public let captureEnd: Double
    public let speechDetected: Bool
    public init(words: [RecognizedWord], captureStart: Double, captureEnd: Double, speechDetected: Bool = true) {
        self.words = words; self.captureStart = captureStart; self.captureEnd = captureEnd; self.speechDetected = speechDetected
    }
}
public struct SyncAnchor: Sendable {
    public let captureTime: Double
    public let movieTime: Double
    public let confidence: Double
    public init(captureTime: Double, movieTime: Double, confidence: Double) {
        self.captureTime = captureTime; self.movieTime = movieTime; self.confidence = confidence
    }
}
public struct MatchResult: Sendable {
    public let confident: Bool
    public let score: Double
    public let runnerUp: Double
    public let contentMatches: Int
    public let timingDeviation: Double
    public let anchor: SyncAnchor?
    public static let noMatch = Self(confident: false, score: 0, runnerUp: 0, contentMatches: 0, timingDeviation: .infinity, anchor: nil)
}
public enum SyncState: Equatable, Sendable {
    case idle, loading, listening, transcribing, finding, synced, interrupted, needsAttention(String)
    public var isAcquiring: Bool {
        switch self { case .loading, .listening, .transcribing, .finding: return true; default: return false }
    }
}
public struct ProviderCredentials: Codable, Sendable, Equatable {
    public var apiKey: String
    public var username: String
    public var password: String
    public var isConfigured: Bool { !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    public init(apiKey: String = "", username: String = "", password: String = "") {
        self.apiKey = apiKey; self.username = username; self.password = password
    }
}
public enum KaptusError: Error, LocalizedError, Equatable {
    case configuration, authentication, quota, offline, invalidCaptions, insecureDownload, response(Int), malformedResponse
    public var errorDescription: String? {
        switch self {
        case .configuration: return "Add your OpenSubtitles API key in Settings to search."
        case .authentication: return "OpenSubtitles could not verify your details. Check your API key and optional account login."
        case .quota: return "Your OpenSubtitles download allowance has been reached. Try again after it resets, or open an SRT file."
        case .offline: return "You're offline. Your saved captions still work from History."
        case .invalidCaptions: return "This file doesn't contain readable SRT captions. Try another file or track."
        case .insecureDownload: return "The provider returned an unsupported download link."
        case .response(let status): return "OpenSubtitles couldn't complete the request (\(status)). Please try again."
        case .malformedResponse: return "OpenSubtitles sent a response Kaptus couldn't read. Please try again."
        }
    }
}
