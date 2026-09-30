import Foundation

public struct CrossLanguageMatch: Sendable {
    public let displayTrack: Int
    public let anchor: SyncAnchor
    public let mapping: TrackTimeMapping?
    public let path: MatchingPath
}
/// Bounded evidence for independent captured utterances, never two decodings of one window.
public struct CrossLanguageMatcher {
    private struct Evidence {
        let window: RecognizedSegment
        let track: Int
        let match: MatchResult
        let helper: (Int, MatchResult)?
    }
    private let profile: LanguageProfile
    private let policy: AutoSeekPolicy
    private let tracks: [(StoredTrack, [CaptionCue])]
    private let indices: [CaptionIndex]
    private var sourceWindows: [UUID: RecognizedSegment] = [:]
    private var previous: Evidence?
    public init(profile: LanguageProfile, policy: AutoSeekPolicy, tracks: [(StoredTrack, [CaptionCue])]) {
        self.profile = profile; self.policy = policy; self.tracks = tracks
        indices = tracks.map { SceneMatcher().buildIndex($0.1, language: $0.0.role == .matchingHelper ? profile.spokenLanguage : $0.0.metadata.language) }
    }
    public mutating func receive(_ segment: RecognizedSegment) -> CrossLanguageMatch? {
        guard segment.speechDetected, !segment.words.isEmpty else { return nil }
        if segment.task == .transcription {
            guard segment.language == profile.spokenLanguage else { return nil }
            sourceWindows = sourceWindows.filter { $0.value.captureEnd >= segment.captureEnd - 18 }
            sourceWindows[segment.windowID] = segment
            if sourceWindows.count > 4, let oldest = sourceWindows.min(by: { $0.value.captureEnd < $1.value.captureEnd }) { sourceWindows.removeValue(forKey: oldest.key) }
            return nil
        }
        guard segment.language == "en", segment.task == .translation else { return nil }
        let matcher = SceneMatcher()
        // Native translation gives each token its decoded utterance interval.
        // Preserve that interval; the surrounding silent capture padding is not dialogue.
        let utterance = segment
        var display: (Int, MatchResult)?
        for i in tracks.indices where tracks[i].0.role == .display && tracks[i].0.metadata.language == profile.captionLanguage {
            let match = matcher.match(utterance, index: indices[i])
            guard match.confident, match.score >= 0.60, match.contentMatches >= 6 else { continue }
            if display == nil || match.score > display!.1.score { display = (i, match) }
        }
        guard let display, display.1.anchor != nil else { return nil }
        var helper: (Int, MatchResult)?
        if policy.allows(profile, path: .helper), let source = sourceWindows.removeValue(forKey: segment.windowID) {
            for i in tracks.indices where tracks[i].0.role == .matchingHelper {
                let match = matcher.match(source, index: indices[i])
                if match.confident && (helper == nil || match.score > helper!.1.score) { helper = (i, match) }
            }
        }
        var path: MatchingPath = helper == nil ? .translated : .helper
        guard policy.allows(profile, path: path) else { return nil }
        let next = Evidence(window: segment, track: display.0, match: display.1, helper: helper)
        guard let prior = previous else { previous = next; return nil }
        // A new decode of overlapping samples is not an independent confirmation.
        guard next.window.captureStart >= prior.window.captureEnd - 0.01 else { return nil }
        guard next.track == prior.track, let anchor = next.match.anchor, let old = prior.match.anchor,
              abs((anchor.movieTime - old.movieTime) - (anchor.captureTime - old.captureTime)) <= 1.25 else {
            previous = next; return nil
        }
        var mapping: TrackTimeMapping?
        if let helper, let oldHelper = prior.helper, helper.0 == oldHelper.0,
           let h = helper.1.anchor, let previousH = oldHelper.1.anchor,
           let helperHash = tracks[helper.0].0.contentHash, let displayHash = tracks[next.track].0.contentHash {
            let offset = anchor.movieTime - h.movieTime
            if abs(offset - (old.movieTime - previousH.movieTime)) > 1.25 {
                guard policy.allows(profile, path: .translated) else { previous = next; return nil }
                path = .translated
            } else {
            mapping = .init(helperHash: helperHash, displayHash: displayHash, offset: offset,
                            sourceStart: min(h.movieTime, previousH.movieTime),
                            sourceEnd: max(h.movieTime, previousH.movieTime))
            }
        } else if path == .helper {
            if policy.allows(profile, path: .translated) { path = .translated }
            else {
            previous = next; return nil
            }
        }
        previous = next
        return .init(displayTrack: next.track, anchor: anchor, mapping: mapping, path: path)
    }
}
