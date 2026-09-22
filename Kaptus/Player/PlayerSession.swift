import AVFoundation
import SwiftUI
import KaptusCore

@MainActor
final class PlayerSession: ObservableObject, Identifiable {
    let id = UUID()
    let title: String
    let demonstration: Bool
    @Published private(set) var state: SyncState = .idle
    @Published private(set) var position: Double = 0
    @Published private(set) var activeCaption = ""
    @Published private(set) var isPlaying = false
    @Published private(set) var adjustment: Double = 0
    @Published private(set) var microphoneDenied = false
    @Published var controlsVisible = true
    @Published var readingSettingsPresented = false
    @Published var orientationLocked = false
    @Published var captionSize: Double = UserDefaults.standard.object(forKey: "captionSize") as? Double ?? 30 {
        didSet { UserDefaults.standard.set(captionSize, forKey: "captionSize") }
    }
    @Published var brightness: Double = 0.15
    @Published private(set) var showSynced = false
    private let speech = SpeechRecognition()
    private let tracks: [(StoredTrack, [CaptionCue])]
    private var trackIndex = 0
    private var index: CaptionIndex
    private var cues: [CaptionCue]
    private var clock = PlaybackClock()
    private var accumulator = TranscriptAccumulator()
    private var timer: Task<Void, Never>?
    private var acquisition: Task<Void, Never>?
    private var timeout: Task<Void, Never>?
    private var hideControlsTask: Task<Void, Never>?
    private var noticeTask: Task<Void, Never>?
    private var hasStarted = false
    private var isForeground = true
    private var attempt = UUID()
    var duration: Double { max(1, cues.last?.end ?? 1) }
    var isAcquiring: Bool { state.isAcquiring }

    init(title: String, tracks: [(StoredTrack, [CaptionCue])], demonstration: Bool = false) {
        self.title = title; self.tracks = tracks; self.demonstration = demonstration
        cues = tracks[0].1; index = SceneMatcher().buildIndex(tracks[0].1)
        speech.onState = { [weak self] in self?.state = $0 }
        speech.onSegment = { [weak self] in self?.receive($0) }
        speech.onFailure = { [weak self] in
            self?.timeout?.cancel()
            self?.state = .needsAttention(String(localized: "Listening stopped. Tap Re-sync to try again."))
            self?.controlsVisible = true
        }
    }
    func startInitial() {
        guard !hasStarted else { return }
        hasStarted = true
        timer = Task { [weak self] in
            while !Task.isCancelled {
                self?.tick()
                try? await Task.sleep(for: .milliseconds(50))
            }
        }
        if demonstration {
            clock = PlaybackClock(now: MonotonicTime.now, position: 4, playing: true)
            state = .synced; showSyncNotice(); tick(); scheduleHideControls()
        } else { resync() }
    }
    func resync() {
        guard isForeground, !demonstration else { return }
        acquisition?.cancel(); timeout?.cancel(); speech.stop()
        attempt = UUID(); let token = attempt
        accumulator = TranscriptAccumulator(); microphoneDenied = false
        state = .loading; controlsVisible = true
        acquisition = Task { [weak self] in
            guard let self else { return }
            let permission = AVAudioSession.sharedInstance().recordPermission
            let allowed: Bool
            if permission == .undetermined {
                allowed = await withCheckedContinuation { continuation in
                    AVAudioSession.sharedInstance().requestRecordPermission { continuation.resume(returning: $0) }
                }
            } else { allowed = permission == .granted }
            guard !Task.isCancelled, self.attempt == token, self.isForeground else { return }
            guard allowed else {
                self.microphoneDenied = true
                self.state = .needsAttention(String(localized: "Microphone access is off. You can still use the timeline, or allow access in iPhone Settings."))
                return
            }
            do {
                try await self.speech.start()
                guard !Task.isCancelled, self.attempt == token else { return }
                self.timeout = Task { [weak self] in
                    try? await Task.sleep(for: .seconds(SyncTuning.attemptSeconds))
                    guard !Task.isCancelled, let self, self.attempt == token, self.state.isAcquiring else { return }
                    self.speech.stop()
                    self.state = .needsAttention(String(localized: "No clear match yet. Wait for dialogue, then tap Re-sync. You can also try another caption track."))
                    self.controlsVisible = true
                }
            } catch {
                guard !Task.isCancelled, self.attempt == token else { return }
                self.speech.stop()
                self.state = .needsAttention(WhisperWorker.modelsReady ? String(localized: "Couldn't start listening. Check that another app isn't using the microphone, then try Re-sync.") : String(localized: "The speech models are missing from this build. Rebuild using the setup instructions."))
            }
        }
    }
    private func receive(_ segment: RecognizedSegment) {
        guard isForeground, state.isAcquiring else { return }
        guard segment.speechDetected, !segment.words.isEmpty else { state = .listening; return }
        state = .finding
        let transcript = accumulator.append(segment)
        // Prepared alternatives are searched without another transcription or network request.
        let matcher = SceneMatcher()
        var winner: (Int, MatchResult)?
        for i in tracks.indices {
            let candidateIndex = i == trackIndex ? index : matcher.buildIndex(tracks[i].1)
            let match = matcher.match(transcript, index: candidateIndex)
            if match.confident && (winner == nil || match.score > winner!.1.score) { winner = (i, match) }
        }
        guard let winner, let anchor = winner.1.anchor else { return }
        speech.stop()
        timeout?.cancel(); acquisition = nil
        if winner.0 != trackIndex {
            trackIndex = winner.0; cues = tracks[trackIndex].1; index = matcher.buildIndex(cues)
        }
        clock.align(to: anchor, now: MonotonicTime.now)
        state = .synced; tick(); showSyncNotice(); scheduleHideControls()
    }
    private func showSyncNotice() {
        showSynced = true; noticeTask?.cancel()
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.showSynced = false
        }
    }
    func togglePlayback() {
        if clock.isPlaying { clock.pause(at: MonotonicTime.now) }
        else { clock.play(at: MonotonicTime.now) }
        tick(); revealControls()
    }
    func seek(to time: Double) {
        clock.seek(to: min(duration, max(0, time)), at: MonotonicTime.now)
        // Manual positioning never starts recognition, and cancels any in-flight acquisition.
        if state.isAcquiring { stopAcquisition(); state = .idle }
        tick(); revealControls()
    }
    func adjust(by seconds: Double) { clock.adjust(by: seconds); tick(); revealControls() }
    func revealControls() { controlsVisible = true; scheduleHideControls() }
    func toggleControls() {
        if controlsVisible && !UIAccessibility.isVoiceOverRunning { controlsVisible = false; hideControlsTask?.cancel() }
        else { revealControls() }
    }
    func scheduleHideControls() {
        hideControlsTask?.cancel()
        guard clock.isPlaying, !state.isAcquiring, !readingSettingsPresented, !UIAccessibility.isVoiceOverRunning else { return }
        hideControlsTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled, let self, self.clock.isPlaying, !self.readingSettingsPresented else { return }
            self.controlsVisible = false
        }
    }
    func foregroundChanged(_ foreground: Bool) {
        isForeground = foreground
        if !foreground && state.isAcquiring {
            stopAcquisition(); state = .interrupted
        }
        tick()
    }
    func interrupted() {
        guard state.isAcquiring else { return }
        stopAcquisition(); state = .interrupted; controlsVisible = true
    }
    private func stopAcquisition() {
        attempt = UUID(); acquisition?.cancel(); acquisition = nil; timeout?.cancel(); speech.stop()
    }
    private func tick() {
        position = min(duration, clock.position(at: MonotonicTime.now))
        if clock.isPlaying && position >= duration { clock.pause(at: MonotonicTime.now); controlsVisible = true }
        isPlaying = clock.isPlaying; adjustment = clock.adjustment
        activeCaption = CaptionParser.activeCue(at: position, in: cues)?.text ?? ""
    }
    func close() {
        stopAcquisition(); speech.stop(releaseModel: true)
        timer?.cancel(); timer = nil; hideControlsTask?.cancel(); noticeTask?.cancel()
        OrientationController.unlock()
    }
}
