import XCTest
@testable import KaptusCore

final class CaptionTests: XCTestCase {
    func testBOMCRLFMultilineFormattingAndMalformedBlocks() throws {
        let srt = "\u{feff}1\r\n00:01:02,50 --> 00:01:05,000\r\n<i>Hello &amp; welcome.</i>\r\n{\\an8}[Door closes]\r\n\r\nbroken block\r\n\r\n3\r\n00:02:00.000 --> 00:02:02.000\r\nGoodnight.\r\n"
        let cues = try CaptionParser.parse(Data(srt.utf8))
        XCTAssertEqual(cues.count, 2)
        XCTAssertEqual(cues[0].start, 62.5)
        XCTAssertEqual(cues[0].text, "Hello & welcome.\n[Door closes]")
        XCTAssertNil(CaptionParser.activeCue(at: 65, in: cues))
        XCTAssertEqual(CaptionParser.activeCue(at: 64, in: cues)?.text, cues[0].text)
    }
    func testMissingSeparatorAndInvalidTimes() throws {
        let text = "1\n00:00:01,000 --> 00:00:02,000\nFirst line\n2\n00:00:03,000 --> 00:00:04,000\nSecond line\n\n3\n00:70:00,000 --> 00:71:00,000\nBad timestamp\n\n4\n00:00:05,000 --> 00:00:04,000\nBackwards"
        let cues = try CaptionParser.parse(Data(text.utf8))
        XCTAssertEqual(cues.map(\.text), ["First line", "Second line"])
    }
    func testArchiveHTMLAndEmptyDataAreRejected() {
        for data in [Data(), Data([0x50, 0x4b, 0x03, 0x04]), Data("<html>Sign in</html>".utf8)] {
            XCTAssertThrowsError(try CaptionParser.parse(data))
        }
    }
    func testUTF16CaptionFile() throws {
        let text = "1\n00:00:01,000 --> 00:00:03,000\nCafÃ© by the sea."
        let data = try XCTUnwrap(text.data(using: .utf16))
        XCTAssertEqual(try CaptionParser.parse(data).first?.text, "CafÃ© by the sea.")
    }
    func testPunctuationSpeakerAndSoundDescriptionsDoNotAffectMatching() {
        XCTAssertEqual(CaptionNormalizer.tokens("MAYA: [whispering] I can't... <i>believe</i> it's dÃ©jÃ -vu!"), ["i", "cant", "believe", "its", "deja", "vu"])
        XCTAssertEqual(CaptionNormalizer.tokens("I canâ€™t believe itâ€™s dÃ©jÃ  vu."), ["i", "cant", "believe", "its", "deja", "vu"])
    }
    func testRankingPrioritizesFullEnglishSDHAndHumanTracks() {
        let tracks = [
            CaptionTrack(fileID: 1, name: "popular", downloads: 99999),
            CaptionTrack(fileID: 2, name: "SDH", sdh: true),
            CaptionTrack(fileID: 3, name: "foreign", language: "fr", sdh: true),
            CaptionTrack(fileID: 4, name: "forced", sdh: true, foreignPartsOnly: true),
            CaptionTrack(fileID: 5, name: "machine", sdh: true, machineTranslated: true, rating: 10)
        ]
        XCTAssertEqual(TrackRanker.ranked(tracks, movie: .init(id: "1", title: "A story")).map(\.id), [2, 5, 1])
    }
    func testEpisodePreservesParentIdentifiers() {
        let show = MovieCandidate(id: "12", title: "Original series", year: 2024, imdbID: 123, tmdbID: 456, kind: .tvShow)
        let episode = show.selecting(season: 2, episode: 7)
        XCTAssertEqual(episode.parentImdbID, 123)
        XCTAssertEqual(episode.parentTmdbID, 456)
        XCTAssertNil(episode.imdbID)
        XCTAssertEqual(episode.kind, .episode)
        XCTAssertTrue(episode.title.contains("S02E07"))
    }
}
