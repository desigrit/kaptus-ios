import SwiftUI

@main
struct KaptusApp: App {
    @UIApplicationDelegateAdaptor(KaptusAppDelegate.self) private var delegate
    @StateObject private var store = AppStore()
    @Environment(\.scenePhase) private var scenePhase
    var body: some Scene {
        WindowGroup {
            RootView().environmentObject(store)
                .tint(Brand.link)
                .onChange(of: scenePhase) { _, phase in store.player?.foregroundChanged(phase == .active) }
        }
    }
}
struct RootView: View {
    @EnvironmentObject private var store: AppStore
    var body: some View {
        Group {
            if store.onboardingComplete { HomeView() }
            else { WelcomeView() }
        }
        .task {
            await store.load()
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
                store.finishOnboarding()
                if ProcessInfo.processInfo.arguments.contains("-demo-player") { store.showSample() }
                if ProcessInfo.processInfo.arguments.contains("-demo-settings") { store.settingsPresented = true }
            }
            #endif
        }
        .sheet(isPresented: $store.settingsPresented) { SettingsView() }
        .fileImporter(isPresented: $store.importPresented, allowedContentTypes: [.subRipText, .plainText, .data]) { result in
            switch result {
            case .success(let url): Task { await store.importFile(url) }
            case .failure(let error): store.errorMessage = error.localizedDescription
            }
        }
        .fullScreenCover(item: $store.player, onDismiss: { store.closePlayer() }) { player in
            PlayerView(session: player, onClose: store.closePlayer)
        }
        .alert(String(localized: "Something needs attention"), isPresented: Binding(get: { store.errorMessage != nil }, set: { if !$0 { store.errorMessage = nil } })) {
            Button("OK", role: .cancel) { store.errorMessage = nil }
        } message: { Text(store.errorMessage ?? "") }
    }
}
