import Foundation

enum ChordQuality: String, Codable, CaseIterable, Identifiable {
    case major, minor, minor7, dominant7, major7, halfDiminished, diminished7, suspended, minorMajor7, dominantFlat9
    var id: String { rawValue }
    var symbol: String {
        switch self {
        case .major: return ""
        case .minor: return "−"
        case .minor7: return "−7"
        case .dominant7: return "7"
        case .major7: return "Δ7"
        case .halfDiminished: return "ø7"
        case .diminished7: return "°7"
        case .suspended: return "sus4"
        case .minorMajor7: return "mMaj7"
        case .dominantFlat9: return "7♭9"
        }
    }
    var label: String {
        switch self {
        case .major: return "Major"
        case .minor: return "Minor"
        case .minor7: return "Minor 7"
        case .dominant7: return "Dominant 7"
        case .major7: return "Major 7"
        case .halfDiminished: return "Half-diminished"
        case .diminished7: return "Diminished 7"
        case .suspended: return "Suspended 4"
        case .minorMajor7: return "Minor major 7"
        case .dominantFlat9: return "Dominant 7♭9"
        }
    }
    var formula: String {
        switch self {
        case .major: return "1 3 5"
        case .minor: return "1 ♭3 5"
        case .minor7: return "1 ♭3 5 ♭7"
        case .dominant7: return "1 3 5 ♭7"
        case .major7: return "1 3 5 7"
        case .halfDiminished: return "1 ♭3 ♭5 ♭7"
        case .diminished7: return "1 ♭3 ♭5 ♭♭7"
        case .suspended: return "1 4 5"
        case .minorMajor7: return "1 ♭3 5 7"
        case .dominantFlat9: return "1 3 5 ♭7 ♭9"
        }
    }

    init?(suffix: String) {
        switch suffix {
        case "": self = .major
        case "m", "min", "-", "−": self = .minor
        case "m7", "min7", "-7", "−7": self = .minor7
        case "7": self = .dominant7
        case "maj7", "M7", "Δ7", "△7": self = .major7
        case "m7b5", "m7♭5", "ø7": self = .halfDiminished
        case "dim7", "°7": self = .diminished7
        case "sus4", "sus": self = .suspended
        case "mMaj7", "mmaj7", "mM7", "m(maj7)", "minMaj7", "mΔ7", "−Δ7": self = .minorMajor7
        case "7b9", "7♭9", "7(b9)", "7(♭9)": self = .dominantFlat9
        default: return nil
        }
    }

}

struct Chord: Equatable, Hashable {
    let root: String
    let accidental: String
    let suffix: String
    let literal: String?
    var name: String { literal ?? root + accidental + suffix }

    /// A recognized chord may have a formula even when its staff spelling needs
    /// accidentals beyond those the notation view can render.
    var formula: String? { parsed?.quality.formula }

    var parsed: (rootIndex: Int, accidental: Int, quality: ChordQuality)? {
        let text = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = ["C", "D", "E", "F", "G", "A", "B"]
        guard let first = text.first, let rootIndex = letters.firstIndex(of: String(first)) else { return nil }
        var remainder = text.dropFirst()
        var alteration = 0
        var count = 0
        while let character = remainder.first, "b♭#♯".contains(character) {
            alteration += (character == "b" || character == "♭") ? -1 : 1
            count += 1
            remainder = remainder.dropFirst()
        }
        guard count <= 2, abs(alteration) == count,
              let quality = ChordQuality(suffix: String(remainder)) else { return nil }
        return (rootIndex, alteration, quality)
    }

    init(root: String, accidental: String = "", suffix: String = "") {
        self.root = root
        self.accidental = accidental
        self.suffix = suffix
        self.literal = nil
    }

    init(literal: String) {
        self.root = ""
        self.accidental = ""
        self.suffix = ""
        self.literal = literal
    }
}

struct PracticeSettings: Codable, Equatable {
    static let flatNames = ["C", "D♭", "D", "E♭", "E", "F", "G♭", "G", "A♭", "A", "B♭", "B"]
    static let sharpNames = ["C", "C♯", "D", "D♯", "E", "F", "F♯", "G", "G♯", "A", "A♯", "B"]
    var roots = Array(0..<12)
    var qualities: [ChordQuality] = [.minor7, .dominant7, .major7]
    var interval: Double = 4
    var sessionMinutes: Double = 5
    var unlimitedSession = false
    var displayMode: ChordDisplayMode = .chordName
    var staffClef: StaffClef = .treble
    var audio = ChordAudioOptions()
    var useSharps = false
    var useCustom = false
    var customText = "Dm7, G7, Cmaj7, Fmaj7, B♭7, E♭maj7"

    init() {}

    private enum CodingKeys: String, CodingKey {
        case roots, qualities, interval, sessionMinutes, unlimitedSession, displayMode, staffClef, audio, useSharps, useCustom, customText
    }

    // Keep existing chord choices when upgrading from the version without a session timer.
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        roots = try values.decodeIfPresent([Int].self, forKey: .roots) ?? Array(0..<12)
        qualities = try values.decodeIfPresent([ChordQuality].self, forKey: .qualities) ?? [.minor7, .dominant7, .major7]
        interval = try values.decodeIfPresent(Double.self, forKey: .interval) ?? 4
        sessionMinutes = try values.decodeIfPresent(Double.self, forKey: .sessionMinutes) ?? 5
        unlimitedSession = try values.decodeIfPresent(Bool.self, forKey: .unlimitedSession) ?? false
        displayMode = (try? values.decode(ChordDisplayMode.self, forKey: .displayMode)) ?? .chordName
        staffClef = (try? values.decode(StaffClef.self, forKey: .staffClef)) ?? .treble
        audio = ((try? values.decode(ChordAudioOptions.self, forKey: .audio)) ?? ChordAudioOptions()).validated()
        useSharps = try values.decodeIfPresent(Bool.self, forKey: .useSharps) ?? false
        useCustom = try values.decodeIfPresent(Bool.self, forKey: .useCustom) ?? false
        customText = try values.decodeIfPresent(String.self, forKey: .customText) ?? "Dm7, G7, Cmaj7"
    }

    var sessionDuration: Double? { unlimitedSession ? nil : sessionMinutes * 60 }

    var rootNames: [String] { useSharps ? Self.sharpNames : Self.flatNames }
    var customChords: [Chord] {
        var seen = Set<String>()
        return customText.components(separatedBy: CharacterSet(charactersIn: ",;\n\r"))
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .map { Chord(literal: $0) }
    }
    var chords: [Chord] {
        if useCustom { return customChords }
        return roots.filter { (0..<12).contains($0) }.sorted().flatMap { index in
            qualities.map { quality in
                let name = rootNames[index]
                return Chord(root: String(name.prefix(1)), accidental: String(name.dropFirst()), suffix: quality.symbol)
            }
        }
    }

    var summary: String {
        useCustom ? "Custom chord list" : "\(roots.count) notes · \(qualities.count) chord types"
    }

    func validated() -> PracticeSettings {
        var result = self
        result.interval = interval.isFinite ? min(300, max(0.5, interval)) : 4
        result.sessionMinutes = sessionMinutes.isFinite ? min(240, max(0.5, sessionMinutes)) : 5
        result.audio = audio.validated()
        result.roots = Array(Set(roots.filter { (0..<12).contains($0) })).sorted()
        result.qualities = ChordQuality.allCases.filter { qualities.contains($0) }
        if result.chords.isEmpty { return PracticeSettings() }
        return result
    }
}

/// A one-shot session countdown, independent of the repeating chord interval.
struct SessionClock {
    private(set) var remaining: Double?
    private(set) var isRunning = false
    private var deadline: Double?
    var isComplete: Bool { remaining == 0 }

    init(duration: Double?) { remaining = duration.map { max(0, $0) } }

    mutating func start(at now: Double) {
        guard !isRunning, !isComplete else { return }
        deadline = remaining.map { now + $0 }
        isRunning = true
    }

    mutating func pause(at now: Double) {
        if let deadline { remaining = max(0, deadline - now) }
        deadline = nil
        isRunning = false
    }

    /// Returns true only on the tick that completes the session.
    mutating func tick(at now: Double) -> Bool {
        guard isRunning, let deadline else { return false }
        remaining = max(0, deadline - now)
        guard remaining == 0 else { return false }
        self.deadline = nil
        isRunning = false
        return true
    }
}

/// A shuffled deck gives every chord a turn, avoiding repeats across deck boundaries.
struct ChordDeck {
    private var pool: [Chord]
    private var remaining: [Chord] = []
    private var last: Chord?

    init(chords: [Chord]) { pool = Array(Set(chords)).sorted { $0.name < $1.name } }

    mutating func next() -> Chord? {
        if remaining.isEmpty {
            remaining = pool.shuffled()
            if remaining.count > 1, remaining.last == last {
                remaining.swapAt(0, remaining.count - 1)
            }
        }
        guard let chord = remaining.popLast() else { return nil }
        last = chord
        return chord
    }
}

/// Uses monotonic time so changing the Mac's clock cannot disrupt a practice interval.
struct PracticeClock {
    private(set) var duration: Double
    private(set) var remaining: Double
    private var deadline: Double?
    var isRunning: Bool { deadline != nil }

    init(duration: Double) {
        self.duration = duration
        remaining = duration
    }
    mutating func start(at now: Double) { deadline = now + remaining }
    mutating func pause(at now: Double) {
        if let deadline { remaining = max(0, deadline - now) }
        deadline = nil
    }
    mutating func reset(duration: Double, at now: Double) {
        self.duration = duration
        remaining = duration
        if isRunning { deadline = now + duration }
    }
    /// Returns true once when the display should advance. Missed background intervals are skipped.
    mutating func tick(at now: Double) -> Bool {
        guard let deadline else { return false }
        remaining = max(0, deadline - now)
        guard remaining <= 0 else { return false }
        remaining = duration
        self.deadline = now + duration
        return true
    }
}
