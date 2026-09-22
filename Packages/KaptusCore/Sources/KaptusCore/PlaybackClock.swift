import Foundation

/// The input time source must be monotonic and include time spent suspended.
public struct PlaybackClock: Sendable {
    private var anchorTime: Double
    private var anchorPosition: Double
    public private(set) var isPlaying: Bool
    public private(set) var rate: Double = 1
    public private(set) var adjustment: Double = 0
    public init(now: Double = 0, position: Double = 0, playing: Bool = false) {
        anchorTime = now; anchorPosition = max(0, position); isPlaying = playing
    }
    public func position(at now: Double) -> Double { max(0, anchorPosition + (isPlaying ? max(0, now - anchorTime) * rate : 0) + adjustment) }
    public mutating func play(at now: Double) { guard !isPlaying else { return }; anchorTime = now; isPlaying = true }
    public mutating func pause(at now: Double) { guard isPlaying else { return }; anchorPosition = position(at: now) - adjustment; anchorTime = now; isPlaying = false }
    public mutating func seek(to position: Double, at now: Double) { anchorPosition = max(0, position) - adjustment; anchorTime = now }
    public mutating func adjust(by seconds: Double) { adjustment += seconds }
    public mutating func align(to anchor: SyncAnchor, now: Double) {
        anchorPosition = max(0, anchor.movieTime + max(0, now - anchor.captureTime) * rate)
        anchorTime = now; adjustment = 0; isPlaying = true
    }
    public mutating func setRate(_ newRate: Double, at now: Double) {
        anchorPosition = position(at: now) - adjustment; anchorTime = now
        rate = min(1.05, max(0.95, newRate))
    }
}

public struct DriftEstimator {
    private var anchors: [SyncAnchor] = []
    public init() {}
    public mutating func add(_ anchor: SyncAnchor) -> Double {
        anchors.append(anchor); anchors = Array(anchors.suffix(12))
        guard let first = anchors.first, anchor.captureTime - first.captureTime >= 60 else { return 1 }
        var slopes: [Double] = []
        for i in anchors.indices {
            for j in anchors.indices where j > i && anchors[j].captureTime - anchors[i].captureTime >= 60 {
                slopes.append((anchors[j].movieTime - anchors[i].movieTime) / (anchors[j].captureTime - anchors[i].captureTime))
            }
        }
        guard !slopes.isEmpty else { return 1 }
        slopes.sort()
        return min(1.05, max(0.95, slopes[slopes.count / 2]))
    }
}
