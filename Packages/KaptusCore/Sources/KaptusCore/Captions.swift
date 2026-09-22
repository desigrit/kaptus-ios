import Foundation

public enum CaptionParser {
    public static let maximumBytes = 16 * 1024 * 1024
    public static func parse(_ data: Data) throws -> [CaptionCue] {
        guard !data.isEmpty, data.count <= maximumBytes, !data.starts(with: [0x50, 0x4b]) else { throw KaptusError.invalidCaptions }
        let decoded: String?
        if data.starts(with: [0xff, 0xfe]) || data.starts(with: [0xfe, 0xff]) { decoded = String(data: data, encoding: .utf16) }
        else { decoded = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .windowsCP1252) ?? String(data: data, encoding: .isoLatin1) }
        guard let decoded else { throw KaptusError.invalidCaptions }
        let text = decoded.replacingOccurrences(of: "\u{feff}", with: "").replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let timePattern = #"^(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})\s*-->\s*(\d{1,2}):(\d{2}):(\d{2})[,.](\d{1,3})"#
        let regex = try NSRegularExpression(pattern: timePattern)
        let lines = text.components(separatedBy: "\n")
        var cues: [CaptionCue] = []
        var current: (Double, Double)?
        var body: [String] = []
        func flush() {
            guard let timing = current else { body = []; return }
            var caption = body.joined(separator: "\n")
            caption = caption.replacingOccurrences(of: #"<[^>]+>|[{][^}]*[}]"#, with: "", options: .regularExpression)
            for (from, to) in [("&amp;","&"),("&lt;","<"),("&gt;",">"),("&quot;","\""),("&apos;","'"),("&#39;","'"),("&nbsp;"," ")] {
                caption = caption.replacingOccurrences(of: from, with: to)
            }
            caption = caption.trimmingCharacters(in: .whitespacesAndNewlines)
            if timing.1 > timing.0, !caption.isEmpty { cues.append(.init(id: cues.count, start: timing.0, end: timing.1, text: caption)) }
            current = nil; body = []
        }
        func seconds(_ match: NSTextCheckingResult, _ line: NSString, _ group: Int) -> Double? {
            let h = Double(line.substring(with: match.range(at: group))) ?? -1
            let m = Double(line.substring(with: match.range(at: group + 1))) ?? -1
            let s = Double(line.substring(with: match.range(at: group + 2))) ?? -1
            let fraction = Double("0." + line.substring(with: match.range(at: group + 3))) ?? 0
            guard h >= 0, (0..<60).contains(m), (0..<60).contains(s) else { return nil }
            return h * 3600 + m * 60 + s + fraction
        }
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let ns = trimmed as NSString
            if let match = regex.firstMatch(in: trimmed, range: NSRange(location: 0, length: ns.length)) {
                // Also recover captions whose blank separator is missing.
                if body.last.flatMap(Int.init) != nil { body.removeLast() }
                flush()
                if let start = seconds(match, ns, 1), let end = seconds(match, ns, 5) { current = (start, end) }
            } else if trimmed.isEmpty { flush() }
            else if current != nil { body.append(line) }
        }
        flush()
        guard !cues.isEmpty else { throw KaptusError.invalidCaptions }
        return cues.sorted { $0.start < $1.start }
    }
    public static func activeCue(at time: Double, in cues: [CaptionCue]) -> CaptionCue? {
        var lo = 0, hi = cues.count
        while lo < hi { let mid = (lo + hi) / 2; if cues[mid].start <= time { lo = mid + 1 } else { hi = mid } }
        guard lo > 0 else { return nil }
        let cue = cues[lo - 1]
        return time < cue.end ? cue : nil
    }
}

public enum CaptionNormalizer {
    public static func tokens(_ text: String) -> [String] {
        var value = text.replacingOccurrences(of: #"<[^>]+>|[{][^}]*[}]|\[[^\]]*\]|\([^)]*\)"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"(?m)^\s*[-\x{2013}\x{2014}]?\s*[A-Z][A-Za-z0-9 .'-]{1,24}:\s*"#, with: " ", options: .regularExpression)
        value = value.replacingOccurrences(of: #"['\x{2018}\x{2019}`\x{00b4}]"#, with: "", options: .regularExpression)
        value = value.folding(options: [.diacriticInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")).lowercased()
        return value.components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
    }
}

public enum TrackRanker {
    public static func ranked(_ tracks: [CaptionTrack], movie: MovieCandidate) -> [CaptionTrack] {
        tracks.filter { $0.language == "en" && !$0.foreignPartsOnly }.sorted {
            let l = priority($0, movie), r = priority($1, movie)
            if l != r { return l.lexicographicallyPrecedes(r) == false }
            return $0.fileID < $1.fileID
        }
    }
    private static func priority(_ track: CaptionTrack, _ movie: MovieCandidate) -> [Double] {
        let release = Set(CaptionNormalizer.tokens(track.release))
        let title = Set(CaptionNormalizer.tokens(movie.title))
        let overlap = Double(release.intersection(title).count) / Double(max(1, title.count))
        return [track.sdh ? 1 : 0, track.machineTranslated ? 0 : 1, track.trusted ? 1 : 0, track.rating, log1p(Double(max(0, track.downloads))), overlap]
    }
}
