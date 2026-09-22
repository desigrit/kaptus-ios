import SwiftUI
import KaptusCore

@MainActor
final class AppStore: ObservableObject {
    @Published var history: [SavedCaptions] = []
    @Published var credentials = ProviderCredentials()
    @Published private(set) var providerRevision = 0
    @Published var player: PlayerSession?
    @Published var errorMessage: String?
    @Published var isImporting = false
    @Published var settingsPresented = false
    @Published var importPresented = false
    @Published var searchRequested = false
    @Published var onboardingComplete: Bool
    let library = CaptionLibrary()
    var provider: OpenSubtitlesRepository { OpenSubtitlesRepository(credentials: credentials) }
    let previewMode: Bool
    init(preview: Bool = false) {
        previewMode = preview
        onboardingComplete = preview || UserDefaults.standard.bool(forKey: "onboardingComplete")
        if !preview {
            do { credentials = try KeychainStore.load() }
            catch { errorMessage = String(localized: "Your saved provider details couldn't be read. Open Settings to add them again.") }
        }
    }
    func load() async {
        do { history = try await library.load() }
        catch { errorMessage = String(localized: "Your caption history couldn't be opened. Your files have not been removed.") }
    }
    func finishOnboarding() { onboardingComplete = true; UserDefaults.standard.set(true, forKey: "onboardingComplete") }
    func saveCredentials(_ value: ProviderCredentials) throws { try KeychainStore.save(value); credentials = value; providerRevision += 1 }
    func importFile(_ url: URL) async {
        isImporting = true; defer { isImporting = false }
        do {
            let item = try await library.importFile(url)
            history = try await library.load()
            finishOnboarding()
            await open(item)
        } catch { errorMessage = error.localizedDescription }
    }
    func open(_ item: SavedCaptions) async {
        do {
            let tracks = try await library.open(item)
            player?.close()
            player = PlayerSession(title: item.movie.title, tracks: tracks)
            history = try await library.load()
        } catch { errorMessage = error.localizedDescription }
    }
    func delete(_ item: SavedCaptions) async {
        do { try await library.delete(item); history = try await library.load() }
        catch { errorMessage = String(localized: "These captions couldn't be removed. Please try again.") }
    }
    func closePlayer() { player?.close(); player = nil }
    func showSample() {
        player = PlayerSession(title: String(localized: "A little way home"), tracks: [(StoredTrack(metadata: CaptionTrack(fileID: -1, name: "Original demo captions"), filename: ""), Demo.cues)], demonstration: true)
    }
}
enum Demo {
    // Original writing, used for previews and tests. No film dialogue is bundled.
    static let cues: [CaptionCue] = [
        .init(id: 1, start: 0, end: 30, text: "Somewhere out there,\na new story is waiting."),
        .init(id: 2, start: 31, end: 38, text: "[Rain taps against the window]"),
        .init(id: 3, start: 39, end: 48, text: "We have time.\nLet's take the long way home."),
        .init(id: 4, start: 49, end: 60, text: "I saved you a seat by the window.")
    ]
}
