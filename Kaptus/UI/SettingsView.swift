import SwiftUI
import KaptusCore

struct SettingsView: View {
    @EnvironmentObject private var store: AppStore
    @Environment(\.dismiss) private var dismiss
    @State private var credentials = ProviderCredentials()
    @State private var errorMessage: String?
    @State private var saved = false
    @AppStorage("captionSize") private var captionSize = 30.0
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 16) {
                        Wordbird(size: 56)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Make yourself comfortable.").font(.headline)
                            Text("A few details, then back to the story.").font(.subheadline).foregroundStyle(.secondary)
                        }
                    }.padding(.vertical, 6)
                }
                Section {
                    SecureField("OpenSubtitles API key", text: $credentials.apiKey)
                        .textInputAutocapitalization(.never).autocorrectionDisabled()
                        .accessibilityIdentifier("settings.apiKey")
                    Link(destination: URL(string: "https://github.com/desigrit/kaptus-ios/blob/main/docs/OPENSUBTITLES.md")!) {
                        Label("How to get your free API key", systemImage: "arrow.up.right.square")
                    }.frame(minHeight: 44)
                } header: { Text("OpenSubtitles") } footer: {
                    Text("Use your own API key. Your details stay in this iPhone's Keychain. Provider limits and terms apply.")
                }
                Section {
                    TextField("Username", text: $credentials.username)
                        .textContentType(.username).textInputAutocapitalization(.never).autocorrectionDisabled()
                    SecureField("Password", text: $credentials.password).textContentType(.password)
                } header: { Text("Account login, optional") } footer: {
                    Text("Some keys require an account login for downloads. Leave both fields empty if your key allows anonymous downloads.")
                }
                Section {
                    Stepper(value: $captionSize, in: 24...44, step: 2) { Text("Caption size: \(Int(captionSize))") }
                    Text("A new story is waiting.").font(.system(size: UIFontMetrics(forTextStyle: .title2).scaledValue(for: captionSize), weight: .semibold))
                        .frame(maxWidth: .infinity).padding(.vertical, 14).accessibilityLabel("Caption size preview")
                } header: { Text("Reading") } footer: { Text("Text also follows your iPhone's accessibility text size.") }
                Section {
                    Label(WhisperWorker.modelsReady ? "Speech models are ready offline" : "Speech models are missing from this build", systemImage: WhisperWorker.modelsReady ? "checkmark.circle" : "exclamationmark.triangle")
                    Label("Microphone stops after a match", systemImage: "mic.slash")
                    Label("Audio is never saved or uploaded", systemImage: "lock")
                } header: { Text("Listening and privacy") }
                Section {
                    Link("Privacy", destination: URL(string: "https://github.com/desigrit/kaptus-ios/blob/main/PRIVACY.md")!)
                    Link("Help and device setup", destination: URL(string: "https://github.com/desigrit/kaptus-ios/blob/main/docs/DEVICE_TESTING.md")!)
                    Link("Kaptus on GitHub", destination: URL(string: "https://github.com/desigrit/kaptus-ios")!)
                    LabeledContent("Version", value: "0.1.0 Preview")
                }
                if !credentials.apiKey.isEmpty {
                    Section {
                        Button("Remove saved provider details", role: .destructive) { credentials = .init() }
                    } footer: { Text("Tap Done to save this change. Your downloaded captions are kept.") }
                }
            }
            .navigationTitle("Settings").navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        if credentials.username.isEmpty != credentials.password.isEmpty {
                            errorMessage = String(localized: "Enter both a username and password, or leave both empty."); return
                        }
                        credentials.apiKey = credentials.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
                        do { try store.saveCredentials(credentials); dismiss() }
                        catch { errorMessage = String(localized: "Your details couldn't be saved securely. Please try again.") }
                    }.accessibilityIdentifier("settings.done")
                }
            }
            .onAppear { credentials = store.credentials }
            .alert("Couldn't save", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
                Button("OK", role: .cancel) {}
            } message: { Text(errorMessage ?? "") }
        }
    }
}
#Preview("Settings") { SettingsView().environmentObject(AppStore(preview: true)) }
