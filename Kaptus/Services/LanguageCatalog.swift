import Foundation
import KaptusCore

actor LanguageCatalog {
    private struct Snapshot: Codable { let fetched: Date; let languages: [CaptionLanguage] }
    private let url: URL
    init(root: URL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("Kaptus", isDirectory: true)) {
        url = root.appendingPathComponent("languages.json")
    }
    func cached() -> [CaptionLanguage] {
        guard let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data) else { return CaptionLanguage.defaults }
        return snapshot.languages
    }
    func refresh(provider: OpenSubtitlesRepository, force: Bool = false) async throws -> [CaptionLanguage] {
        if !force, let data = try? Data(contentsOf: url), let snapshot = try? JSONDecoder().decode(Snapshot.self, from: data), Date().timeIntervalSince(snapshot.fetched) < 7 * 86400 { return snapshot.languages }
        let languages = try await provider.languages()
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        var directory = url.deletingLastPathComponent(); var values = URLResourceValues(); values.isExcludedFromBackup = true; try directory.setResourceValues(values)
        try JSONEncoder().encode(Snapshot(fetched: Date(), languages: languages)).write(to: url, options: [.atomic, .completeFileProtectionUntilFirstUserAuthentication])
        return languages
    }
}
