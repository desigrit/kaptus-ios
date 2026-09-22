import Foundation

public enum SyncTuning {
    public static let minimumScore = 0.48
    public static let minimumContentWords = 3
    public static let runnerUpMargin = 0.05
    public static let maximumTimingDeviation = 1.75
    public static let windowSeconds = 6.0
    public static let strideSeconds = 3.0
    public static let attemptSeconds = 35.0
}
public struct CaptionIndex: Sendable {
    struct Word: Sendable { let text: String; let time: Double; let cue: Int; let weight: Double }
    let words: [Word]
    let positions: [String: [Int]]
}
public struct SceneMatcher: Sendable {
    public init() {}
    private static let stopWords = Set("a an and are as at be but by for from he her him his i in is it me my of on or she so that the their them they this to was we were what with you your".split(separator: " ").map(String.init))
    private func weight(_ word: String, frequency: Int) -> Double {
        if Self.stopWords.contains(word) { return 0.12 }
        switch frequency { case ...1: return 1; case ...3: return 0.9; case ...12: return 0.75; default: return 0.55 }
    }
    public func buildIndex(_ cues: [CaptionCue]) -> CaptionIndex {
        let tokens = cues.map { CaptionNormalizer.tokens($0.text) }
        let frequencies = Dictionary(tokens.flatMap { $0 }.map { ($0, 1) }, uniquingKeysWith: +)
        var words: [CaptionIndex.Word] = []
        var positions: [String: [Int]] = [:]
        for (i, cue) in cues.enumerated() {
            for (j, token) in tokens[i].enumerated() {
                positions[token, default: []].append(words.count)
                words.append(.init(text: token, time: cue.start + (cue.end - cue.start) * (Double(j) + 0.5) / Double(tokens[i].count), cue: i, weight: weight(token, frequency: frequencies[token, default: 0])))
            }
        }
        return CaptionIndex(words: words, positions: positions)
    }
    public func match(_ segment: RecognizedSegment, index: CaptionIndex, expectedTime: Double? = nil) -> MatchResult {
        let query: [(token: String, source: RecognizedWord, weight: Double)] = segment.words.flatMap { word in
            CaptionNormalizer.tokens(word.text).map { ($0, word, weight($0, frequency: index.positions[$0]?.count ?? 0)) }
        }
        guard query.filter({ !Self.stopWords.contains($0.token) }).count >= SyncTuning.minimumContentWords, !index.words.isEmpty else { return .noMatch }
        var votes: [Int: Double] = [:]
        for (i, word) in query.enumerated() {
            for position in index.positions[word.token, default: []] {
                if let expectedTime, abs(index.words[position].time - expectedTime) > 120 { continue }
                votes[position - i, default: 0] += word.weight
            }
        }
        // Keep distinct scenes represented, even when one passage receives many nearby offset votes.
        var offsets: [Int] = []
        for candidate in votes.sorted(by: { $0.value == $1.value ? $0.key < $1.key : $0.value > $1.value }) {
            if offsets.allSatisfy({ abs($0 - candidate.key) > 4 }) { offsets.append(candidate.key) }
            if offsets.count == 32 { break }
        }
        var results: [MatchResult] = []
        for offset in offsets {
            let lower = max(0, offset - 8), upper = min(index.words.count, offset + query.count + 8)
            guard upper > lower else { continue }
            let window = Array(index.words[lower..<upper])
            let cols = window.count + 1
            var grid = Array(repeating: 0.0, count: (query.count + 1) * cols)
            for row in 1...query.count {
                for col in 1...window.count {
                    let similar = similarity(query[row - 1].token, window[col - 1].text)
                    grid[row * cols + col] = max(grid[(row - 1) * cols + col - 1] + similar * query[row - 1].weight, max(grid[(row - 1) * cols + col], grid[row * cols + col - 1]))
                }
            }
            var row = query.count, col = window.count
            var pairs: [(Int, Int)] = []
            while row > 0 && col > 0 {
                let sim = similarity(query[row - 1].token, window[col - 1].text)
                if sim > 0 && abs(grid[row * cols + col] - grid[(row - 1) * cols + col - 1] - sim * query[row - 1].weight) < 0.0001 {
                    pairs.append((row - 1, col - 1)); row -= 1; col -= 1
                } else if grid[(row - 1) * cols + col] >= grid[row * cols + col - 1] { row -= 1 }
                else { col -= 1 }
            }
            guard !pairs.isEmpty else { continue }
            let total = query.reduce(0) { $0 + $1.weight }
            let matched = pairs.reduce(0.0) { $0 + query[$1.0].weight * similarity(query[$1.0].token, window[$1.1].text) }
            let deltas = pairs.map { window[$0.1].time - (query[$0.0].source.start + query[$0.0].source.end) / 2 }.sorted()
            let median = deltas[deltas.count / 2]
            let deviations = deltas.map { abs($0 - median) }.sorted()
            let score = min(1, matched / max(0.01, total))
            results.append(.init(confident: false, score: score, runnerUp: 0, contentMatches: pairs.filter { !Self.stopWords.contains(query[$0.0].token) }.count, timingDeviation: deviations[deviations.count / 2], anchor: .init(captureTime: segment.captureEnd, movieTime: segment.captureEnd + median, confidence: score)))
        }
        results.sort { $0.score > $1.score }
        guard let best = results.first, let anchor = best.anchor else { return .noMatch }
        let runner = results.dropFirst().first { abs(($0.anchor?.movieTime ?? 0) - anchor.movieTime) > 15 }?.score ?? 0
        let confident = best.score >= SyncTuning.minimumScore && best.contentMatches >= SyncTuning.minimumContentWords && best.score - runner >= SyncTuning.runnerUpMargin && best.timingDeviation <= SyncTuning.maximumTimingDeviation
        return .init(confident: confident, score: best.score, runnerUp: runner, contentMatches: best.contentMatches, timingDeviation: best.timingDeviation, anchor: anchor)
    }
    private func similarity(_ left: String, _ right: String) -> Double {
        if left == right { return 1 }
        let a = Array(left), b = Array(right)
        guard a.count >= 5, b.count >= 5, abs(a.count - b.count) <= 1 else { return 0 }
        var i = 0, j = 0, edits = 0
        while i < a.count && j < b.count {
            if a[i] == b[j] { i += 1; j += 1; continue }
            edits += 1; if edits > 1 { return 0 }
            if a.count >= b.count { i += 1 }
            if b.count >= a.count { j += 1 }
        }
        if i < a.count || j < b.count { edits += 1 }
        return edits <= 1 ? 0.65 : 0
    }
}
public struct TranscriptAccumulator {
    private var words: [RecognizedWord] = []
    public init() {}
    public mutating func append(_ segment: RecognizedSegment) -> RecognizedSegment {
        let cutoff = segment.captureEnd - 18
        // Replace the overlap with the newer decoding. Never concatenate duplicate windows.
        words.removeAll { $0.end <= cutoff || $0.start >= segment.captureStart }
        words.append(contentsOf: segment.words)
        words = Array(words.filter { $0.end > cutoff }.suffix(96))
        return .init(words: words, captureStart: words.first?.start ?? segment.captureStart, captureEnd: segment.captureEnd, speechDetected: segment.speechDetected)
    }
}
