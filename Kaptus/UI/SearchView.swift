import SwiftUI
import KaptusCore

struct SearchView: View {
    @EnvironmentObject private var store: AppStore
    @State private var query = ""
    @State private var results: [MovieCandidate] = []
    @State private var loading = false
    @State private var errorMessage: String?
    @State private var selected: MovieCandidate?
    @State private var episodeShow: MovieCandidate?
    @State private var pendingOpen: SavedCaptions?
    @State private var retry = 0
    @State private var preparedNotice = false
    var body: some View {
        List {
            if !store.credentials.isConfigured {
                Section {
                    EmptyState(title: "Bring your own key", message: "Add your OpenSubtitles API key to find movies and TV episodes. You can always open an SRT file without one.", symbol: "key")
                    Button("Set up OpenSubtitles") { store.settingsPresented = true }.frame(minHeight: 44)
                    Button("Open SRT file") { store.importPresented = true }.frame(minHeight: 44)
                }
            } else if let errorMessage {
                Section {
                    Text(errorMessage).foregroundStyle(.secondary)
                    Button("Try again") { retry += 1 }.frame(minHeight: 44)
                }
            } else if loading {
                ProgressView("Looking for your story…").frame(maxWidth: .infinity).padding()
            } else if query.trimmingCharacters(in: .whitespacesAndNewlines).count < 2 {
                EmptyState(title: "What are you watching?", message: "Search by title, then check the year. For a TV show, choose the season and episode next.", symbol: "sparkle.magnifyingglass")
            } else if results.isEmpty {
                EmptyState(title: "No titles found", message: "Try fewer words or the original title.", symbol: "magnifyingglass")
            } else {
                Section {
                    ForEach(results) { movie in
                        Button {
                            if movie.kind == .tvShow { episodeShow = movie } else { selected = movie }
                        } label: {
                            HStack(alignment: .center, spacing: 16) {
                                Image(systemName: movie.kind == .tvShow ? "tv" : "film").font(.title2).frame(width: 32).foregroundStyle(.secondary)
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(movie.title).font(.headline).foregroundStyle(.primary)
                                    HStack(spacing: 8) {
                                        if let year = movie.year { Text(String(year)).fontWeight(.semibold) }
                                        Text(movie.kind == .tvShow ? "TV show" : "Movie")
                                    }.font(.subheadline).foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                            }.padding(.vertical, 8)
                        }
                    }
                } footer: { Text("Titles and subtitles from OpenSubtitles.com") }
            }
            if preparedNotice {
                Label("Prepared for theater. Find it in History.", systemImage: "checkmark.circle")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Find your story").navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "Movie or TV show title")
        .autocorrectionDisabled()
        .task(id: "\(query)|\(retry)|\(store.credentials.apiKey.isEmpty)") { await search() }
        .sheet(item: $episodeShow) { show in
            EpisodePicker(show: show) { episode in
                episodeShow = nil
                // Native sheet dismissal completes before the next sheet is presented.
                Task { try? await Task.sleep(for: .milliseconds(400)); selected = episode }
            }
        }
        .sheet(item: $selected, onDismiss: {
            if let item = pendingOpen { pendingOpen = nil; Task { await store.open(item) } }
        }) { movie in
            PreparationView(movie: movie) { item, open in
                preparedNotice = !open
                pendingOpen = open ? item : nil
                selected = nil
            }
        }
    }
    private func search() async {
        errorMessage = nil; results = []
        guard store.credentials.isConfigured, query.trimmingCharacters(in: .whitespacesAndNewlines).count >= 2 else { loading = false; return }
        loading = true
        do {
            try await Task.sleep(for: .milliseconds(350))
            let matches = try await store.provider.searchMovies(query)
            try Task.checkCancellation()
            results = matches; loading = false
        } catch is CancellationError { }
        catch { if !Task.isCancelled { errorMessage = error.localizedDescription; loading = false } }
    }
}
struct EpisodePicker: View {
    let show: MovieCandidate
    let onSelect: (MovieCandidate) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var season = 1
    @State private var episode = 1
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(show.title).font(.title2.bold()) }
                Section {
                    Stepper("Season \(season)", value: $season, in: 1...100)
                    Stepper("Episode \(episode)", value: $episode, in: 1...1000)
                } footer: { Text("Use the season and episode numbers from your streaming service.") }
                Section { Button("Find captions") { onSelect(show.selecting(season: season, episode: episode)) }.frame(minHeight: 44) }
            }
            .navigationTitle("Choose an episode").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
        }.presentationDetents([.medium, .large])
    }
}
struct PreparationView: View {
    let movie: MovieCandidate
    let onReady: (SavedCaptions, Bool) -> Void
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var tracks: [CaptionTrack] = []
    @State private var loading = true
    @State private var downloading = false
    @State private var savedCount = 0
    @State private var errorMessage: String?
    @State private var lastSaved: SavedCaptions?
    @State private var loadAttempt = 0
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Image(systemName: movie.kind == .episode ? "tv" : "film").font(.largeTitle).foregroundStyle(.secondary).accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(movie.title).font(.title.bold())
                        if let year = movie.year { Text(String(year)).foregroundStyle(.secondary) }
                    }
                    if loading { ProgressView("Finding English captions…") }
                    else if tracks.isEmpty && errorMessage == nil {
                        Text("No complete English captions were found. Try opening an SRT file instead.").foregroundStyle(.secondary)
                    } else if !tracks.isEmpty {
                        Label(tracks[0].sdh ? "English, with sound descriptions" : "English captions", systemImage: "captions.bubble")
                        Text("We pick complete captions first, favoring SDH and trusted, human-authored tracks.").font(.subheadline).foregroundStyle(.secondary)
                        if downloading {
                            ProgressView("Saving captions…")
                            Text("\(savedCount) saved").font(.footnote).foregroundStyle(.secondary)
                        } else {
                            PrimaryAction(title: "Watch now", symbol: "play.fill") { Task { await prepare(count: 1, open: true) } }
                            Text("Uses up to 1 download from your provider allowance.").font(.footnote).foregroundStyle(.secondary)
                            Button { Task { await prepare(count: min(3, tracks.count), open: false) } } label: {
                                Label("Prepare for theater", systemImage: "arrow.down.circle").frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.bordered)
                            Text("Saves up to \(min(3, tracks.count)) tracks for offline matching. Each new track uses one provider download. Existing saved tracks are reused.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                    if let errorMessage {
                        Text(errorMessage).foregroundStyle(.secondary)
                        if let lastSaved {
                            Button("Open saved captions") { onReady(lastSaved, true) }.frame(minHeight: 44)
                        } else if !downloading { Button("Try again") { loadAttempt += 1 }.frame(minHeight: 44) }
                    }
                }.padding(24).frame(maxWidth: 600)
            }
            .navigationTitle("Your captions").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(downloading) } }
            .interactiveDismissDisabled(downloading)
            .task(id: loadAttempt) {
                loading = true; errorMessage = nil
                do { tracks = try await store.provider.findTracks(for: movie); loading = false }
                catch { if !Task.isCancelled { errorMessage = error.localizedDescription; loading = false } }
            }
        }.presentationDetents([.large])
    }
    private func prepare(count: Int, open: Bool) async {
        guard !downloading else { return }
        guard open || WhisperWorker.modelsReady else {
            errorMessage = String(localized: "This build is missing its speech models. See the build setup guide before preparing for offline use.")
            return
        }
        downloading = true; errorMessage = nil; savedCount = 0
        defer { downloading = false }
        do {
            let provider = store.provider
            var saved = store.history.first { $0.movie.id == movie.id }
            for track in tracks.prefix(count) {
                try Task.checkCancellation()
                if saved?.tracks.contains(where: { $0.metadata.fileID == track.fileID }) != true {
                    let data = try await provider.download(track)
                    saved = try await store.library.save(data: data, movie: movie, track: track)
                    lastSaved = saved
                    store.history = try await store.library.load()
                }
                savedCount += 1
            }
            guard let saved else { throw KaptusError.invalidCaptions }
            _ = try await store.library.open(saved)
            onReady(saved, open)
        } catch { errorMessage = error.localizedDescription }
    }
}
#Preview("Search setup") { NavigationStack { SearchView() }.environmentObject(AppStore(preview: true)) }
