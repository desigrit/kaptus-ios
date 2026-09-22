import SwiftUI
import KaptusCore

struct HomeView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 24) {
                        HStack(alignment: .top, spacing: 20) {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Follow every line.").font(.largeTitle.bold()).fixedSize(horizontal: false, vertical: true)
                                Text("Find your story. We'll find your place.")
                                    .font(.body).foregroundStyle(.secondary)
                            }
                            Spacer(minLength: 0)
                            Wordbird(size: 68)
                        }
                        VStack(spacing: 12) {
                            PrimaryAction(title: "Find a movie or TV show", symbol: "magnifyingglass") { store.searchRequested = true }
                                .accessibilityIdentifier("home.find")
                            Button { store.importPresented = true } label: {
                                Label("Open SRT file", systemImage: "folder").frame(maxWidth: .infinity, minHeight: 44)
                            }.buttonStyle(.bordered).accessibilityIdentifier("home.import")
                        }
                        if store.isImporting { ProgressView("Opening captionsâ€¦") }
                        if !store.credentials.isConfigured {
                            Button { store.settingsPresented = true } label: {
                                Label("Set up OpenSubtitles for online search", systemImage: "key")
                                    .font(.footnote).frame(minHeight: 44, alignment: .leading)
                            }.accessibilityIdentifier("home.setup")
                        }
                    }.padding(.vertical, 12)
                }.listRowBackground(Color.clear).listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 16, trailing: 0))
                Section("History") {
                    if store.history.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Your next story starts here.").font(.headline)
                            Text("Captions you open or download will be saved here for another night.")
                                .font(.subheadline).foregroundStyle(.secondary)
                            Button("Try a sample") { store.showSample() }.frame(minHeight: 44).accessibilityIdentifier("home.sample")
                        }.padding(.vertical, 10)
                    } else {
                        ForEach(store.history) { item in
                            Button { Task { await store.open(item) } } label: {
                                HStack(spacing: 14) {
                                    Image(systemName: item.movie.kind == .movie ? "film" : "tv").font(.title2).foregroundStyle(.secondary).frame(width: 32)
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(item.movie.title).font(.headline).foregroundStyle(.primary)
                                        Label(WhisperWorker.modelsReady ? "Ready offline" : "Captions saved", systemImage: WhisperWorker.modelsReady ? "checkmark.circle" : "arrow.down.circle")
                                            .font(.caption).foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(.tertiary)
                                }.padding(.vertical, 8)
                            }
                            .swipeActions { Button("Delete", role: .destructive) { Task { await store.delete(item) } } }
                        }
                    }
                }
                Section {
                    Label("Made for quiet screens and big stories.", systemImage: "moon")
                        .font(.footnote).foregroundStyle(.secondary)
                }.listRowBackground(Color.clear)
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Kaptus")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { store.settingsPresented = true } label: { Image(systemName: "gearshape") }
                        .accessibilityLabel("Settings").accessibilityIdentifier("home.settings")
                }
            }
            .navigationDestination(isPresented: $store.searchRequested) { SearchView() }
        }
    }
}
#Preview("Home, light") { HomeView().environmentObject(AppStore(preview: true)) }
#Preview("Home, dark") { HomeView().environmentObject(AppStore(preview: true)).preferredColorScheme(.dark) }
