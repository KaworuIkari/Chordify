import Foundation

enum ChordDisplayMode: String, Codable, CaseIterable, Identifiable {
    case chordName, staff, both
    var id: String { rawValue }
    var label: String {
        switch self {
        case .chordName: return "Chords"
        case .staff: return "Staff only"
        case .both: return "Both"
        }
    }
}

enum StaffClef: String, Codable, CaseIterable, Identifiable {
    case treble, bass
    var id: String { rawValue }
    var label: String { self == .treble ? "Treble" : "Bass" }
    var symbol: String { self == .treble ? "𝄞" : "𝄢" }
    var octaveShift: Int { self == .treble ? 0 : -2 }
    var bottomPosition: Int { self == .treble ? 30 : 18 } // E4 / G2

    func writtenNotes(_ notes: [StaffNote]) -> [StaffNote] {
        notes.map {
            StaffNote(letter: $0.letter, octave: $0.octave + octaveShift,
                      accidental: $0.accidental, midi: $0.midi + octaveShift * 12,
                      diatonicPosition: $0.diatonicPosition + octaveShift * 7)
        }
    }
}

/// A written pitch, retaining its letter name even when enharmonic to another pitch.
struct StaffNote: Equatable {
    let letter: String
    let octave: Int
    let accidental: Int
    let midi: Int
    let diatonicPosition: Int

    var spokenName: String {
        let alteration: String
        switch accidental {
        case -2: alteration = " double flat"
        case -1: alteration = " flat"
        case 1: alteration = " sharp"
        case 2: alteration = " double sharp"
        default: alteration = ""
        }
        return "\(letter)\(alteration) \(octave)"
    }
}

extension Chord {
    /// Close-position chord tones, rooted on the written note in octave 4.
    /// Unknown symbols and spellings requiring triple accidentals are unsupported.
    var staffNotes: [StaffNote]? {
        guard let parsed else { return nil }
        let rootIndex = parsed.rootIndex
        let rootAccidental = parsed.accidental
        let letters = ["C", "D", "E", "F", "G", "A", "B"]
        let naturals = [0, 2, 4, 5, 7, 9, 11]
        let intervals: [(Int, Int)]
        switch parsed.quality {
        case .major: intervals = [(0, 0), (2, 4), (4, 7)]
        case .minor: intervals = [(0, 0), (2, 3), (4, 7)]
        case .minor7: intervals = [(0, 0), (2, 3), (4, 7), (6, 10)]
        case .dominant7: intervals = [(0, 0), (2, 4), (4, 7), (6, 10)]
        case .major7: intervals = [(0, 0), (2, 4), (4, 7), (6, 11)]
        case .halfDiminished: intervals = [(0, 0), (2, 3), (4, 6), (6, 10)]
        case .diminished7: intervals = [(0, 0), (2, 3), (4, 6), (6, 9)]
        case .suspended: intervals = [(0, 0), (3, 5), (4, 7)]
        case .minorMajor7: intervals = [(0, 0), (2, 3), (4, 7), (6, 11)]
        case .dominantFlat9: intervals = [(0, 0), (2, 4), (4, 7), (6, 10), (8, 13)]
        }
        let rootMIDI = 60 + naturals[rootIndex] + rootAccidental
        var notes: [StaffNote] = []
        for (degree, semitones) in intervals {
            let absoluteLetter = rootIndex + degree
            let index = absoluteLetter % 7
            let octave = 4 + absoluteLetter / 7
            let midi = rootMIDI + semitones
            let naturalMIDI = (octave + 1) * 12 + naturals[index]
            let alteration = midi - naturalMIDI
            guard (-2...2).contains(alteration) else { return nil }
            notes.append(StaffNote(letter: letters[index], octave: octave, accidental: alteration,
                                   midi: midi, diatonicPosition: octave * 7 + index))
        }
        return notes
    }
}
