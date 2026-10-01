import SwiftUI
import KaptusCore

struct LanguageSelection: View {
    @EnvironmentObject private var store: AppStore
    @Binding var profile: LanguageProfile
    var includeUnknown = false
    private var languages: [CaptionLanguage] {
        var result = store.captionLanguages
        if includeUnknown { result.insert(.unknown, at: 0) }
        if !result.contains(where: { $0.code == profile.captionLanguage }) { result.append(.init(code: profile.captionLanguage, name: store.languageName(profile.captionLanguage))) }
        return result
    }
    var body: some View {
        Picker("Caption language", selection: $profile.captionLanguage) {
            ForEach(languages) { Text($0.name).tag($0.code) }
        }.accessibilityIdentifier("languages.captions")
        Picker("Spoken language", selection: $profile.spokenLanguage) {
            ForEach(SpokenLanguage.choices) { Text($0.name).tag($0.code) }
            ForEach(store.captionLanguages.filter { !Set(SpokenLanguage.choices.map(\.code)).contains($0.code) && !["zh-cn", "zh-tw"].contains($0.code) }) {
                Text($0.name).tag($0.code)
            }
        }.accessibilityIdentifier("languages.spoken")
    }
}
struct ImportLanguageView: View {
    let url: URL
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var profile = LanguageProfile(captionLanguage: "und", spokenLanguage: "und")
    var body: some View {
        NavigationStack {
            Form {
                Section { Text(url.lastPathComponent).textSelection(.enabled) }
                Section { LanguageSelection(profile: $profile, includeUnknown: true) } footer: {
                    Text("Tell us the language in this file and the language you hear. Unknown files still work with manual timing.")
                }
                Section {
                    Text("Manual timing is available for every language. Auto-seek works with English captions and supported spoken languages. Other languages use the timeline.").font(.footnote).foregroundStyle(.secondary)
                    Button("Open captions") {
                        store.pendingImportURL = nil; dismiss()
                        Task { await store.importFile(url, languages: profile) }
                    }.frame(minHeight: 44).accessibilityIdentifier("import.open")
                }
            }
            .navigationTitle("Caption languages").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { store.pendingImportURL = nil; dismiss() } } }
        }
    }
}
struct MultilingualModelSettings: View {
    @ObservedObject var models: SpeechModelManager
    var body: some View {
        Section {
            Text("One download, shared by nine spoken languages.").font(.subheadline)
            Text("Download this model to find your place in English captions while listening to Mandarin, Japanese, Spanish, French, German, Korean, Hindi, Telugu or Tamil audio.")
                .font(.footnote).foregroundStyle(.secondary)
            if models.isDownloading {
                ProgressView(value: models.progress)
                Text("\(Int(models.progress * 100))% downloaded").font(.caption.monospacedDigit())
                Button("Cancel download") { models.cancel() }.frame(minHeight: 44)
            } else if models.isReady {
                Label("Multilingual model saved offline", systemImage: "checkmark.circle")
                Button("Delete multilingual model", role: .destructive) { models.delete() }.frame(minHeight: 44)
            } else {
                Button("Download multilingual model (190 MB)") { models.download() }.frame(minHeight: 44)
                Text("Download once, then use auto-seek offline. English audio needs no extra download. Interrupted downloads can be resumed.").font(.footnote).foregroundStyle(.secondary)
            }
            if let message = models.errorMessage { Text(message).font(.footnote).foregroundStyle(.secondary) }
        } header: { Text("Multilingual speech model") }
    }
}
#Preview("Import languages") { ImportLanguageView(url: URL(fileURLWithPath: "/sample.srt")).environmentObject(AppStore(preview: true)) }
