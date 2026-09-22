import SwiftUI
import AVFoundation

struct PlayerView: View {
    @ObservedObject var session: PlayerSession
    let onClose: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dynamicTypeSize) private var dynamicType
    @State private var scrubPosition: Double = 0
    @State private var scrubbing = false
    @State private var originalBrightness: CGFloat?
    @ScaledMetric(relativeTo: .title2) private var captionScale: CGFloat = 1
    var body: some View {
        GeometryReader { geometry in
            let compact = geometry.size.width > geometry.size.height && !dynamicType.isAccessibilitySize
            ZStack {
                Color.black.ignoresSafeArea()
                    .contentShape(Rectangle()).onTapGesture { session.toggleControls() }
                    .accessibilityLabel("Show or hide player controls")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { session.toggleControls() }
                ScrollView {
                    Text(session.activeCaption)
                        .font(.system(size: session.captionSize * captionScale, weight: .semibold))
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white)
                        .frame(maxWidth: 780)
                        .padding(.horizontal, compact ? 56 : 24)
                        .frame(minHeight: max(80, geometry.size.height - (session.controlsVisible ? (compact ? 154 : 250) : 100)))
                        .accessibilityIdentifier("player.caption")
                        .accessibilityAddTraits(.updatesFrequently)
                }
                .scrollIndicators(.hidden)
                .frame(maxWidth: .infinity)
                .padding(.top, 56)
                .padding(.bottom, session.controlsVisible ? (compact ? 98 : 194) : 44)
                .contentShape(Rectangle())
                .onTapGesture { session.toggleControls() }

                VStack(spacing: 0) {
                    topBar
                    Spacer(minLength: 12)
                    if session.controlsVisible {
                        controlPanel(compact: compact)
                            .padding(.horizontal, compact ? 24 : 20).padding(.bottom, 12)
                            .background(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .bottom))
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .tint(Brand.yellow)
        .statusBarHidden(!session.controlsVisible)
        .persistentSystemOverlays(session.controlsVisible ? .automatic : .hidden)
        .sheet(isPresented: $session.readingSettingsPresented, onDismiss: { session.scheduleHideControls() }) {
            readingSettings
        }
        .onAppear {
            activateDisplay()
            session.startInitial()
        }
        .onDisappear { restoreDisplay() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active { activateDisplay() } else { restoreDisplay() }
            session.foregroundChanged(phase == .active, background: phase == .background)
        }
        .onChange(of: session.brightness) { _, value in if scenePhase == .active { UIScreen.main.brightness = value } }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)) { _ in session.interrupted() }
        .onReceive(NotificationCenter.default.publisher(for: AVAudioSession.routeChangeNotification)) { notification in
            if let value = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt,
               let reason = AVAudioSession.RouteChangeReason(rawValue: value),
               reason == .oldDeviceUnavailable || reason == .newDeviceAvailable { session.interrupted() }
        }
    }
    private var topBar: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                if session.controlsVisible {
                    Button(action: onClose) { Image(systemName: "chevron.down").frame(width: 44, height: 44) }
                        .accessibilityLabel("Close caption player").accessibilityIdentifier("player.close")
                }
                if abs(session.adjustment) >= 0.05 {
                    Text(String(format: "%+.1fs", session.adjustment))
                        .font(.caption.monospacedDigit()).foregroundStyle(.gray)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Color.white.opacity(0.06), in: Capsule())
                        .accessibilityLabel(Text("Caption adjustment \(session.adjustment, specifier: "%+.1f") seconds"))
                        .accessibilityIdentifier("player.offset")
                }
                Spacer(minLength: 4)
                if session.controlsVisible {
                    Button { session.readingSettingsPresented = true } label: { Image(systemName: "gearshape").frame(width: 44, height: 44) }
                        .accessibilityLabel("Player settings").accessibilityIdentifier("player.settings")
                }
            }.foregroundStyle(.gray).padding(.horizontal, 14)
            if let status = statusText {
                Text(status).font(.subheadline.weight(.medium))
                    .foregroundStyle(session.state == .synced ? Color.gray : Brand.yellow)
                    .multilineTextAlignment(.center).padding(.horizontal, 24)
                    .accessibilityIdentifier("player.status")
            }
        }
    }
    private var statusText: String? {
        switch session.state {
        case .idle: return nil
        case .loading: return String(localized: "Getting ready to listen")
        case .listening: return String(localized: "Listening")
        case .transcribing: return String(localized: "Transcribing dialogue")
        case .finding: return String(localized: "Finding your place")
        case .synced: return session.showSynced ? String(localized: "Synced") : nil
        case .interrupted: return String(localized: "Listening paused. Tap Re-sync when you're ready.")
        case .needsAttention(let message): return message
        }
    }
    @ViewBuilder
    private func controlPanel(compact: Bool) -> some View {
        VStack(spacing: compact ? 4 : 14) {
            if !compact {
                Text(session.title).font(.subheadline).foregroundStyle(.gray).lineLimit(2)
            }
            HStack(spacing: 12) {
                Text(timeString(session.position)).font(.caption.monospacedDigit()).foregroundStyle(.gray)
                Slider(value: Binding(get: { scrubbing ? scrubPosition : session.position }, set: { scrubPosition = $0 }), in: 0...session.duration, onEditingChanged: { editing in
                    if editing { scrubPosition = session.position; session.beginInteraction() }
                    scrubbing = editing
                    if !editing { session.seek(to: scrubPosition); session.endInteraction() }
                }).accessibilityLabel("Caption timeline").accessibilityIdentifier("player.timeline")
                Text(timeString(session.duration)).font(.caption.monospacedDigit()).foregroundStyle(.gray)
            }
            ViewThatFits(in: .horizontal) {
                HStack(spacing: compact ? 18 : 12) { timingButtons; Spacer(minLength: 0); playButton; Spacer(minLength: 0); resyncButton }
                VStack(spacing: 8) {
                    HStack { playButton; Spacer(); resyncButton }
                    HStack { timingButtons }
                }
            }
            if session.microphoneDenied {
                Button("Open iPhone Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                }.font(.subheadline).frame(minHeight: 44)
            }
        }
    }
    private var timingButtons: some View {
        HStack(spacing: 8) {
            Button { session.adjust(by: -0.5) } label: { Text("-0.5s").monospacedDigit().frame(minWidth: 52, minHeight: 44) }
                .accessibilityLabel("Show captions half a second later").accessibilityIdentifier("player.delay")
            Button { session.adjust(by: 0.5) } label: { Text("+0.5s").monospacedDigit().frame(minWidth: 52, minHeight: 44) }
                .accessibilityLabel("Show captions half a second earlier").accessibilityIdentifier("player.advance")
        }.font(.subheadline).foregroundStyle(.gray).buttonStyle(.plain)
    }
    private var playButton: some View {
        Button { session.togglePlayback() } label: {
            Label(session.isPlaying ? "Pause" : "Play", systemImage: session.isPlaying ? "pause.fill" : "play.fill")
                .font(.headline).frame(minHeight: 44)
        }.foregroundStyle(.white).accessibilityIdentifier("player.play")
    }
    private var resyncButton: some View {
        Button { session.resync() } label: {
            Label("Re-sync", systemImage: "waveform").font(.subheadline).frame(minHeight: 44)
        }.foregroundStyle(Brand.yellow).disabled(session.isAcquiring || session.demonstration).accessibilityIdentifier("player.resync")
    }
    private var readingSettings: some View {
        NavigationStack {
            Form {
                Section("Caption text") {
                    Stepper(value: $session.captionSize, in: 24...44, step: 2) { Text("Size: \(Int(session.captionSize))") }
                    Text("Somewhere, a story is waiting.")
                        .font(.system(size: session.captionSize * captionScale, weight: .semibold))
                        .multilineTextAlignment(.center).frame(maxWidth: .infinity).padding(.vertical, 12)
                }
                Section("Theater comfort") {
                    Slider(value: $session.brightness, in: 0.01...1) {
                        Text("Screen brightness")
                    } minimumValueLabel: {
                        Image(systemName: "sun.min")
                    } maximumValueLabel: { Image(systemName: "sun.max") }
                    .accessibilityLabel("Screen brightness")
                    Button("Very dim") { session.brightness = 0.03 }.frame(minHeight: 44)
                    Toggle("Lock current orientation", isOn: $session.orientationLocked)
                        .onChange(of: session.orientationLocked) { _, locked in
                            if locked { OrientationController.lockCurrent() } else { OrientationController.unlock() }
                        }
                }
                Section {
                    Text("Positive adjustments show captions earlier. Negative adjustments show them later.")
                    Text("Re-sync listens again. Moving the timeline keeps you in control and does not turn on the microphone.")
                }.font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle("Player settings").navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { session.readingSettingsPresented = false } } }
        }.presentationDetents([.medium, .large]).preferredColorScheme(.dark)
    }
    private func activateDisplay() {
        if originalBrightness == nil { originalBrightness = UIScreen.main.brightness }
        UIScreen.main.brightness = session.brightness
        UIApplication.shared.isIdleTimerDisabled = true
    }
    private func restoreDisplay() {
        if let originalBrightness { UIScreen.main.brightness = originalBrightness }
        originalBrightness = nil
        UIApplication.shared.isIdleTimerDisabled = false
    }
    private func timeString(_ seconds: Double) -> String {
        let value = Int(max(0, seconds))
        return String(format: "%d:%02d", value / 60, value % 60)
    }
}
#Preview("Cinema") {
    PlayerView(session: PlayerSession(title: "A little way home", tracks: [(.init(metadata: .init(fileID: -1, name: "Demo"), filename: ""), Demo.cues)], demonstration: true), onClose: {})
}
