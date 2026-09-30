import Foundation
import CryptoKit
import KaptusCore

actor CaptionLibrary {
    private let root: URL
    private let metadata: URL
    private var items: [SavedCaptions] = []
    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Kaptus", isDirectory: true)) {
        self.root = root; metadata = root.appendingPathComponent("library.json")
    }
    func load() throws -> [SavedCaptions] {
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true, attributes: [.protectionKey: FileProtectionType.completeUntilFirstUserAuthentication])
        var url = root; var values = URLResourceValues(); values.isExcludedFromBackup = true; try url.setResourceValues(values)
        if FileManager.default.fileExists(atPath: metadata.path) { items = try JSONDecoder().decode([SavedCaptions].self, from: Data(contentsOf: metadata)) }
        items = items.filter { item in item.tracks.contains { $0.role == .display && $0.metadata.language == item.languages.captionLanguage && FileManager.default.fileExists(atPath: root.appendingPathComponent($0.filename).path) } }
        return items.sorted { $0.lastOpened > $1.lastOpened }
    }
    func save(data: Data, movie: MovieCandidate, track: CaptionTrack, languages: LanguageProfile = .init(), role: CaptionTrackRole = .display) throws -> SavedCaptions {
        _ = try CaptionParser.parse(data)
        guard role == .matchingHelper || track.language == languages.captionLanguage else { throw KaptusError.invalidCaptions }
        let filename = UUID().uuidString + ".srt"
        let url = root.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let savedTrack = StoredTrack(metadata: track, filename: filename, role: role, contentHash: SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined())
        let previous = items
        var item = items.first { $0.movie.id == movie.id && $0.languages == languages } ?? SavedCaptions(movie: movie, tracks: [], languages: languages)
        let oldTrack = item.tracks.first { $0.metadata.id == track.id && $0.role == role }
        item.tracks.removeAll { $0.metadata.id == track.id }
        item.tracks.append(savedTrack); item.lastOpened = Date()
        items.removeAll { $0.id == item.id }; items.insert(item, at: 0)
        do { try persist() }
        catch { items = previous; try? FileManager.default.removeItem(at: url); throw error }
        if let oldTrack { try? FileManager.default.removeItem(at: root.appendingPathComponent(oldTrack.filename)) }
        return item
    }
    func open(_ item: SavedCaptions) throws -> [(StoredTrack, [CaptionCue])] {
        let tracks = item.tracks.filter { $0.role == .matchingHelper || $0.metadata.language == item.languages.captionLanguage }.compactMap { track -> (StoredTrack, [CaptionCue])? in
            // Stored names are generated UUID filenames, never provider paths.
            guard track.filename == URL(fileURLWithPath: track.filename).lastPathComponent,
                  let data = try? Data(contentsOf: root.appendingPathComponent(track.filename)),
                  let cues = try? CaptionParser.parse(data) else { return nil }
            let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            guard track.contentHash == nil || track.contentHash == hash else { return nil }
            return (StoredTrack(metadata: track.metadata, filename: track.filename, role: track.role, contentHash: hash), cues)
        }
        guard tracks.contains(where: { $0.0.role == .display }) else { throw KaptusError.invalidCaptions }
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i].lastOpened = Date(); try persist() }
        return tracks
    }
    func importFile(_ url: URL, languages: LanguageProfile = .init(captionLanguage: "und", spokenLanguage: "und")) throws -> SavedCaptions {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }
        var coordinationError: NSError?
        var result: Result<Data, Error>?
        NSFileCoordinator().coordinate(readingItemAt: url, options: [], error: &coordinationError) { coordinatedURL in
            result = Result {
                let size = try coordinatedURL.resourceValues(forKeys: [.fileSizeKey]).fileSize ?? 0
                guard size <= CaptionParser.maximumBytes else { throw KaptusError.invalidCaptions }
                return try Data(contentsOf: coordinatedURL, options: .mappedIfSafe)
            }
        }
        if let coordinationError { throw coordinationError }
        guard let result else { throw KaptusError.invalidCaptions }
        let data = try result.get()
        let title = url.deletingPathExtension().lastPathComponent
        let movie = MovieCandidate(id: "local-" + UUID().uuidString, title: title)
        return try save(data: data, movie: movie, track: CaptionTrack(fileID: 0, name: url.lastPathComponent, language: languages.captionLanguage), languages: languages)
    }
    func delete(_ item: SavedCaptions) throws {
        let previous = items
        items.removeAll { $0.id == item.id }
        do { try persist() } catch { items = previous; throw error }
        for track in item.tracks {
            guard track.filename == URL(fileURLWithPath: track.filename).lastPathComponent else { continue }
            try? FileManager.default.removeItem(at: root.appendingPathComponent(track.filename))
        }
    }
    func cachedData(for track: CaptionTrack) -> Data? {
        for saved in items {
            for existing in saved.tracks where existing.metadata.fileID == track.fileID && existing.metadata.language == track.language {
                guard existing.filename == URL(fileURLWithPath: existing.filename).lastPathComponent,
                      let data = try? Data(contentsOf: root.appendingPathComponent(existing.filename)),
                      (try? CaptionParser.parse(data)) != nil else { continue }
                let hash = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
                if existing.contentHash == nil || existing.contentHash == hash { return data }
            }
        }
        return nil
    }
    func saveMapping(_ mapping: TrackTimeMapping) throws {
        var mappings: [TrackTimeMapping] = []
        let url = root.appendingPathComponent("track-mappings.json")
        if let data = try? Data(contentsOf: url) { mappings = (try? JSONDecoder().decode([TrackTimeMapping].self, from: data)) ?? [] }
        mappings.removeAll { $0.helperHash == mapping.helperHash && $0.displayHash == mapping.displayHash && max($0.sourceStart, mapping.sourceStart) <= min($0.sourceEnd, mapping.sourceEnd) }
        mappings.append(mapping)
        try JSONEncoder().encode(Array(mappings.suffix(128))).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
    func mappings(helperHash: String, displayHash: String) -> [TrackTimeMapping] {
        guard let data = try? Data(contentsOf: root.appendingPathComponent("track-mappings.json")),
              let all = try? JSONDecoder().decode([TrackTimeMapping].self, from: data) else { return [] }
        return all.filter { $0.helperHash == helperHash && $0.displayHash == displayHash }
    }
    private func persist() throws {
        try JSONEncoder().encode(items).write(to: metadata, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
