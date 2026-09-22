import Foundation
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
        items = items.filter { item in item.tracks.contains { FileManager.default.fileExists(atPath: root.appendingPathComponent($0.filename).path) } }
        return items.sorted { $0.lastOpened > $1.lastOpened }
    }
    func save(data: Data, movie: MovieCandidate, track: CaptionTrack) throws -> SavedCaptions {
        _ = try CaptionParser.parse(data)
        let filename = UUID().uuidString + ".srt"
        let url = root.appendingPathComponent(filename)
        try data.write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        let savedTrack = StoredTrack(metadata: track, filename: filename)
        let previous = items
        var item = items.first { $0.movie.id == movie.id } ?? SavedCaptions(movie: movie, tracks: [])
        let oldTrack = item.tracks.first { $0.metadata.id == track.id }
        item.tracks.removeAll { $0.metadata.id == track.id }
        item.tracks.append(savedTrack); item.lastOpened = Date()
        items.removeAll { $0.id == item.id }; items.insert(item, at: 0)
        do { try persist() }
        catch { items = previous; try? FileManager.default.removeItem(at: url); throw error }
        if let oldTrack { try? FileManager.default.removeItem(at: root.appendingPathComponent(oldTrack.filename)) }
        return item
    }
    func open(_ item: SavedCaptions) throws -> [(StoredTrack, [CaptionCue])] {
        let tracks = item.tracks.compactMap { track -> (StoredTrack, [CaptionCue])? in
            // Stored names are generated UUID filenames, never provider paths.
            guard track.filename == URL(fileURLWithPath: track.filename).lastPathComponent,
                  let data = try? Data(contentsOf: root.appendingPathComponent(track.filename)),
                  let cues = try? CaptionParser.parse(data) else { return nil }
            return (track, cues)
        }
        guard !tracks.isEmpty else { throw KaptusError.invalidCaptions }
        if let i = items.firstIndex(where: { $0.id == item.id }) { items[i].lastOpened = Date(); try persist() }
        return tracks
    }
    func importFile(_ url: URL) throws -> SavedCaptions {
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
        return try save(data: data, movie: movie, track: CaptionTrack(fileID: 0, name: url.lastPathComponent))
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
    private func persist() throws {
        try JSONEncoder().encode(items).write(to: metadata, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
    }
}
