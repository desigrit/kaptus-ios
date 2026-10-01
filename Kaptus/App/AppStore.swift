import SwiftUI
import Combine
import KaptusCore

@MainActor
final class AppStore: ObservableObject {
    @Published var captionLanguages = CaptionLanguage.defaults
    @Published var defaultLanguages = LanguageProfile(
        captionLanguage: UserDefaults.standard.string(forKey: "captionLanguage") ?? "en",
        spokenLanguage: UserDefaults.standard.string(forKey: "spokenLanguage") ?? "en")
    @Published var pendingImportURL: URL?
    @Published var languageCatalogNotice: String?
    let models = SpeechModelManager()
    private var modelObservation: AnyCancellable?
    private let catalog = LanguageCatalog()
    let autoSeekPolicy = AutoSeekPolicy.production
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
        modelObservation = models.objectWillChange.sink { [weak self] in
            // Published changes arrive before their value is assigned. Read on the next main-actor turn.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.player?.updateMultilingualModelPath(self.models.path)
                self.objectWillChange.send()
            }
        }
        if !preview {
            do { credentials = try KeychainStore.load() }
            catch { errorMessage = String(localized: "Your saved provider details couldn't be read. Open Settings to add them again.") }
        }
    }
    func load() async {
        captionLanguages = await catalog.cached()
        do { history = try await library.load() }
        catch { errorMessage = String(localized: "Your caption history couldn't be opened. Your files have not been removed.") }
        await refreshLanguages()
    }
    func refreshLanguages(force: Bool = false) async {
        guard credentials.isConfigured else { return }
        do { captionLanguages = try await catalog.refresh(provider: provider, force: force); languageCatalogNotice = nil }
        catch { languageCatalogNotice = String(localized: "Showing saved language choices. Connect to refresh the full provider catalog.") }
    }
    func saveLanguageDefaults(_ profile: LanguageProfile) {
        defaultLanguages = profile
        UserDefaults.standard.set(profile.captionLanguage, forKey: "captionLanguage")
        UserDefaults.standard.set(profile.spokenLanguage, forKey: "spokenLanguage")
    }
    func languageName(_ code: String) -> String { captionLanguages.first(where: { $0.code == code })?.name ?? (code == "und" ? String(localized: "Unknown") : code) }
    func capability(_ item: SavedCaptions) -> AutoSeekCapability {
        let ready = item.languages.spokenLanguage == "en" ? WhisperWorker.modelsReady : models.isReady
        return autoSeekPolicy.capability(item.languages, modelReady: ready, hasHelper: item.tracks.contains { $0.role == .matchingHelper })
    }
    func finishOnboarding() { onboardingComplete = true; UserDefaults.standard.set(true, forKey: "onboardingComplete") }
    func saveCredentials(_ value: ProviderCredentials) throws { try KeychainStore.save(value); credentials = value; providerRevision += 1; Task { await refreshLanguages(force: true) } }
    func importFile(_ url: URL, languages: LanguageProfile = .init(captionLanguage: "und", spokenLanguage: "und")) async {
        isImporting = true; defer { isImporting = false }
        do {
            let item = try await library.importFile(url, languages: languages)
            history = try await library.load()
            finishOnboarding()
            await open(item)
        } catch { errorMessage = error.localizedDescription }
    }
    func open(_ item: SavedCaptions) async {
        do {
            let tracks = try await library.open(item)
            // A saved foreign-language item may be opened while launch-time verification is pending.
            // This verifies the private file only; native initialization stays inside the listening deadline.
            if autoSeekPolicy.allows(item.languages, path: .translated) || autoSeekPolicy.allows(item.languages, path: .helper) {
                await models.verifyExisting()
            }
            player?.close()
            player = PlayerSession(title: item.movie.title, tracks: tracks, languages: item.languages, capabilityPolicy: autoSeekPolicy, multilingualModelPath: models.path)
            player?.onValidatedMapping = { [library] mapping in Task { try? await library.saveMapping(mapping) } }
            history = try await library.load()
        } catch { errorMessage = error.localizedDescription }
    }
    func delete(_ item: SavedCaptions) async {
        do { try await library.delete(item); history = try await library.load() }
        catch { errorMessage = String(localized: "These captions couldn't be removed. Please try again.") }
    }
    func closePlayer() { player?.close(); player = nil }
    func showManualSample() {
        let cues = [CaptionCue(id: 1, start: 0, end: 60, text: "هناك حكاية جديدة تنتظرك.")]
        player = PlayerSession(title: String(localized: "Original multilingual sample"), tracks: [(.init(metadata: .init(fileID: -2, name: "Original sample", language: "ar"), filename: ""), cues)], languages: .init(captionLanguage: "ar", spokenLanguage: "ar"))
    }
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
