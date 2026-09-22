import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    Wordbird(size: 96).padding(.top, 32)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Follow every line.").font(.largeTitle.bold())
                        Text("Your own captions, wherever the story takes you.").font(.title2).foregroundStyle(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 18) {
                        Label("Choose a movie, TV episode, or SRT file.", systemImage: "captions.bubble")
                        Label("Listen briefly to find your place.", systemImage: "waveform")
                        Label("Read along. Your audio stays on your iPhone.", systemImage: "iphone")
                    }.font(.body)
                    VStack(spacing: 14) {
                        PrimaryAction(title: "Find a movie or TV show", symbol: "magnifyingglass") {
                            store.finishOnboarding(); store.searchRequested = true
                        }.accessibilityIdentifier("welcome.find")
                        Button { store.finishOnboarding(); store.importPresented = true } label: {
                            Label("Open SRT file", systemImage: "folder").frame(maxWidth: .infinity, minHeight: 44)
                        }.buttonStyle(.bordered).accessibilityIdentifier("welcome.import")
                        Text("Local files work without an account. Online search uses your own OpenSubtitles API key.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }.padding(24).frame(maxWidth: 600)
            }
            .navigationTitle("Kaptus").navigationBarTitleDisplayMode(.inline)
        }
    }
}
#Preview("Welcome") { WelcomeView().environmentObject(AppStore(preview: true)) }
