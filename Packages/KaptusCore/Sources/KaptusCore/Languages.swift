import Foundation

/// Provider codes are preserved, including pt-br, zh-cn and zh-tw.
public struct CaptionLanguage: Codable, Hashable, Identifiable, Sendable {
    public let code: String
    public let name: String
    public var id: String { code }
    public init(code: String, name: String) { self.code = code; self.name = name }
    public static let unknown = Self(code: "und", name: "Unknown")
    public static let defaults: [Self] = [
        .init(code: "af", name: "Afrikaans"),
        .init(code: "sq", name: "Albanian"),
        .init(code: "ar", name: "Arabic"),
        .init(code: "hy", name: "Armenian"),
        .init(code: "az", name: "Azerbaijani"),
        .init(code: "eu", name: "Basque"),
        .init(code: "be", name: "Belarusian"),
        .init(code: "bn", name: "Bengali"),
        .init(code: "bs", name: "Bosnian"),
        .init(code: "bg", name: "Bulgarian"),
        .init(code: "ca", name: "Catalan"),
        .init(code: "zh-cn", name: "Chinese (simplified)"),
        .init(code: "zh-tw", name: "Chinese (traditional)"),
        .init(code: "hr", name: "Croatian"),
        .init(code: "cs", name: "Czech"),
        .init(code: "da", name: "Danish"),
        .init(code: "nl", name: "Dutch"),
        .init(code: "en", name: "English"),
        .init(code: "eo", name: "Esperanto"),
        .init(code: "et", name: "Estonian"),
        .init(code: "fi", name: "Finnish"),
        .init(code: "fr", name: "French"),
        .init(code: "gl", name: "Galician"),
        .init(code: "ka", name: "Georgian"),
        .init(code: "de", name: "German"),
        .init(code: "el", name: "Greek"),
        .init(code: "gu", name: "Gujarati"),
        .init(code: "he", name: "Hebrew"),
        .init(code: "hi", name: "Hindi"),
        .init(code: "hu", name: "Hungarian"),
        .init(code: "is", name: "Icelandic"),
        .init(code: "id", name: "Indonesian"),
        .init(code: "it", name: "Italian"),
        .init(code: "ja", name: "Japanese"),
        .init(code: "kn", name: "Kannada"),
        .init(code: "kk", name: "Kazakh"),
        .init(code: "km", name: "Khmer"),
        .init(code: "ko", name: "Korean"),
        .init(code: "lv", name: "Latvian"),
        .init(code: "lt", name: "Lithuanian"),
        .init(code: "mk", name: "Macedonian"),
        .init(code: "ms", name: "Malay"),
        .init(code: "ml", name: "Malayalam"),
        .init(code: "mr", name: "Marathi"),
        .init(code: "mn", name: "Mongolian"),
        .init(code: "ne", name: "Nepali"),
        .init(code: "no", name: "Norwegian"),
        .init(code: "fa", name: "Persian"),
        .init(code: "pl", name: "Polish"),
        .init(code: "pt-br", name: "Portuguese (Brazil)"),
        .init(code: "pt-pt", name: "Portuguese (Portugal)"),
        .init(code: "pa", name: "Punjabi"),
        .init(code: "ro", name: "Romanian"),
        .init(code: "ru", name: "Russian"),
        .init(code: "sr", name: "Serbian"),
        .init(code: "si", name: "Sinhala"),
        .init(code: "sk", name: "Slovak"),
        .init(code: "sl", name: "Slovenian"),
        .init(code: "es", name: "Spanish"),
        .init(code: "sw", name: "Swahili"),
        .init(code: "sv", name: "Swedish"),
        .init(code: "ta", name: "Tamil"),
        .init(code: "te", name: "Telugu"),
        .init(code: "th", name: "Thai"),
        .init(code: "tr", name: "Turkish"),
        .init(code: "uk", name: "Ukrainian"),
        .init(code: "ur", name: "Urdu"),
        .init(code: "vi", name: "Vietnamese"),
        .init(code: "cy", name: "Welsh")
    ]
}
public struct LanguageProfile: Codable, Hashable, Sendable {
    public var captionLanguage: String
    public var spokenLanguage: String
    public init(captionLanguage: String = "en", spokenLanguage: String = "en") {
        self.captionLanguage = captionLanguage; self.spokenLanguage = spokenLanguage
    }
}
public struct SpokenLanguage: Identifiable, Sendable {
    public let code: String
    public let name: String
    public var id: String { code }
    public static let choices: [Self] = [
        .init(code: "en", name: "English"), .init(code: "zh", name: "Mandarin"),
        .init(code: "ja", name: "Japanese"), .init(code: "es", name: "Spanish"),
        .init(code: "fr", name: "French"), .init(code: "de", name: "German"),
        .init(code: "ko", name: "Korean"), .init(code: "hi", name: "Hindi"),
        .init(code: "te", name: "Telugu"), .init(code: "ta", name: "Tamil"),
        .init(code: "und", name: "Other or unknown")
    ]
    public static func helperCode(for language: String) -> String { language == "zh" ? "zh-cn" : language }
}
public enum CaptionTrackRole: String, Codable, Hashable, Sendable { case display, matchingHelper }
public enum RecognitionTask: String, Codable, Hashable, Sendable { case transcription, translation }
public enum SpeechModelID: String, Codable, Hashable, Sendable { case english, multilingual }
public enum MatchingPath: String, Codable, Hashable, Sendable { case english, helper, translated }
public struct RecognitionConfiguration: Sendable, Equatable {
    public let sessionID: UUID
    public let sourceLanguage: String
    public let model: SpeechModelID
    public let tasks: [RecognitionTask]
    public let modelPath: String?
    public init(sessionID: UUID = UUID(), sourceLanguage: String = "en", model: SpeechModelID = .english, tasks: [RecognitionTask] = [.transcription], modelPath: String? = nil) {
        self.sessionID = sessionID; self.sourceLanguage = sourceLanguage; self.model = model; self.tasks = tasks; self.modelPath = modelPath
    }
}
public enum AutoSeekCapability: Equatable, Sendable {
    case ready, modelRequired, manual(String)
    public var canListen: Bool { self == .ready }
}
/// No foreign-language path ships as validated until physical-device evidence is reviewed.
public struct AutoSeekPolicy: Sendable {
    private static let targets = Set(["zh", "ja", "es", "fr", "de", "ko", "hi", "te", "ta"])
    private let validated: Set<String>
    public init(validatedPairs: Set<String> = []) { validated = validatedPairs }
    public static let production = Self()
    public static func evaluation(languages: Set<String>) -> Self {
        Self(validatedPairs: Set(languages.flatMap { ["\($0):helper", "\($0):translated"] }))
    }
    public func capability(_ profile: LanguageProfile, modelReady: Bool, hasHelper: Bool = false) -> AutoSeekCapability {
        guard profile.captionLanguage == "en" else { return .manual("Auto-seek is available only with English captions. Use the timeline for this language combination.") }
        if profile.spokenLanguage == "en" { return modelReady ? .ready : .modelRequired }
        guard Self.targets.contains(profile.spokenLanguage) else { return .manual("Use the timeline to start these captions. Auto-seek is not available for this spoken language.") }
        let helperReady = hasHelper && validated.contains("\(profile.spokenLanguage):helper")
        let translationReady = validated.contains("\(profile.spokenLanguage):translated")
        guard helperReady || translationReady else {
            return .manual("Manual timing. Auto-seek for this language is awaiting real-device validation.")
        }
        return modelReady ? .ready : .modelRequired
    }
    public func allows(_ profile: LanguageProfile, path: MatchingPath) -> Bool {
        if path == .english { return profile == LanguageProfile() }
        return profile.captionLanguage == "en" && Self.targets.contains(profile.spokenLanguage) && validated.contains("\(profile.spokenLanguage):\(path.rawValue)")
    }
}
public struct TrackTimeMapping: Codable, Sendable {
    public let helperHash: String
    public let displayHash: String
    public let offset: Double
    public let sourceStart: Double
    public let sourceEnd: Double
    public init(helperHash: String, displayHash: String, offset: Double, sourceStart: Double, sourceEnd: Double) {
        self.helperHash = helperHash; self.displayHash = displayHash; self.offset = offset; self.sourceStart = sourceStart; self.sourceEnd = sourceEnd
    }
    public func displayTime(for time: Double) -> Double? {
        guard (sourceStart...sourceEnd).contains(time) else { return nil }
        return time + offset
    }
}
