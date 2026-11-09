import Foundation

enum ChordInstrument: String, Codable, CaseIterable, Identifiable {
    case piano, electricPiano, guitar, strings
    var id: String { rawValue }
    var label: String {
        switch self {
        case .piano: return "Piano"
        case .electricPiano: return "Electric piano"
        case .guitar: return "Nylon guitar"
        case .strings: return "Strings"
        }
    }
    /// General MIDI programs use zero-based numbering in the sampler API.
    var midiProgram: UInt8 {
        switch self {
        case .piano: return 0
        case .electricPiano: return 4
        case .guitar: return 24
        case .strings: return 48
        }
    }
}

enum ChordTone: String, Codable, CaseIterable, Identifiable {
    case root, third, fifth, seventh, ninth
    var id: String { rawValue }
    var label: String {
        switch self {
        case .root: return "Root (1)"
        case .third: return "3rd / sus4"
        case .fifth: return "5th"
        case .seventh: return "7th"
        case .ninth: return "9th"
        }
    }
}

struct ChordAudioOptions: Codable, Equatable {
    var enabled = true
    var instrument: ChordInstrument = .piano
    var selectedTones: [ChordTone] = ChordTone.allCases
    var volume: Double = 0.5

    init() {}
    private enum CodingKeys: String, CodingKey { case enabled, instrument, selectedTones, volume }
    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        enabled = (try? values.decode(Bool.self, forKey: .enabled)) ?? true
        instrument = (try? values.decode(ChordInstrument.self, forKey: .instrument)) ?? .piano
        selectedTones = (try? values.decode([ChordTone].self, forKey: .selectedTones)) ?? ChordTone.allCases
        volume = (try? values.decode(Double.self, forKey: .volume)) ?? 0.5
    }

    func validated() -> ChordAudioOptions {
        var result = self
        result.volume = volume.isFinite ? min(1, max(0, volume)) : 0.5
        result.selectedTones = ChordTone.allCases.filter { selectedTones.contains($0) }
        if result.selectedTones.isEmpty { result.selectedTones = ChordTone.allCases }
        return result
    }

    /// Chord tones retain the same written register as the staff, including altered ninths.
    /// The second voice is the third on ordinary chords and the fourth on sus4 chords.
    func midiNotes(for chord: Chord, clef: StaffClef) -> [UInt8] {
        guard let written = chord.staffNotes else { return [] }
        let notes = clef.writtenNotes(written)
        return zip(ChordTone.allCases, notes).compactMap { role, note in
            guard selectedTones.contains(role), (0...127).contains(note.midi) else { return nil }
            return UInt8(note.midi)
        }
    }
}

@MainActor protocol ChordSoundPlaying: AnyObject {
    func play(notes: [UInt8], instrument: ChordInstrument, volume: Double, duration: Double) throws
    func stop()
    func setVolume(_ volume: Double)
}
