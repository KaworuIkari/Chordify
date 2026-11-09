import Foundation

@main
struct StaffNotationTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
    static func main() {
        let expected: [ChordQuality: [Int]] = [
            .major: [0, 4, 7], .minor: [0, 3, 7], .minor7: [0, 3, 7, 10],
            .dominant7: [0, 4, 7, 10], .major7: [0, 4, 7, 11],
            .halfDiminished: [0, 3, 6, 10], .diminished7: [0, 3, 6, 9],
            .suspended: [0, 5, 7], .minorMajor7: [0, 3, 7, 11],
            .dominantFlat9: [0, 4, 7, 10, 13]
        ]
        for root in PracticeSettings.flatNames + PracticeSettings.sharpNames {
            for quality in ChordQuality.allCases {
                let chord = Chord(root: String(root.prefix(1)), accidental: String(root.dropFirst()), suffix: quality.symbol)
                guard let notes = chord.staffNotes else { fatalError("Missing \(chord.name)") }
                check(notes.map { $0.midi - notes[0].midi } == expected[quality]!, "Intervals for \(chord.name)")
                let steps = quality == .suspended ? [0, 3, 4] : Array([0, 2, 4, 6, 8].prefix(notes.count))
                check(chord.formula == quality.formula, "Formula for \(chord.name)")
                check(notes.map { $0.diatonicPosition - notes[0].diatonicPosition } == steps, "Letters for \(chord.name)")
                check(notes[0].octave == 4, "Root octave for \(chord.name)")
            }
        }
        func spell(_ name: String) -> [String] {
            guard let notes = Chord(literal: name).staffNotes else { fatalError("Missing \(name)") }
            return notes.map { "\($0.letter):\($0.accidental):\($0.octave)" }
        }
        check(spell("C#") == ["C:1:4", "E:1:4", "G:1:4"], "C sharp major")
        check(spell("Gbmaj7") == ["G:-1:4", "B:-1:4", "D:-1:5", "F:0:5"], "G flat major seventh")
        check(spell("Bdim7") == ["B:0:4", "D:0:5", "F:0:5", "A:-1:5"], "B diminished seventh")
        check(spell("F#maj7").last == "E:1:5", "E sharp spelling")
        check(spell("C♭7").last == "B:-2:4", "Double flat spelling")
        check(Chord(literal: "C♭7").staffNotes!.last!.spokenName == "B double flat 4", "Accessible name")
        check(spell("C7b9") == ["C:0:4", "E:0:4", "G:0:4", "B:-1:4", "D:-1:5"], "C dominant flat nine")
        check(spell("F#mMaj7") == ["F:1:4", "A:0:4", "C:1:5", "E:1:5"], "F sharp minor major seventh")
        let formulas: [ChordQuality: String] = [.major: "1 3 5", .minor: "1 ♭3 5", .minor7: "1 ♭3 5 ♭7", .dominant7: "1 3 5 ♭7", .major7: "1 3 5 7", .halfDiminished: "1 ♭3 ♭5 ♭7", .diminished7: "1 ♭3 ♭5 ♭♭7", .suspended: "1 4 5", .minorMajor7: "1 ♭3 5 7", .dominantFlat9: "1 3 5 ♭7 ♭9"]
        for quality in ChordQuality.allCases { check(quality.formula == formulas[quality], "Formula for \(quality)") }
        let oldSettings = try! JSONDecoder().decode(PracticeSettings.self, from: Data(#"{"roots":[0,7],"qualities":["minor7","dominant7","major7"]}"#.utf8))
        check(oldSettings.roots == [0,7] && oldSettings.qualities == [.minor7, .dominant7, .major7], "Old settings preserved")
        check(PracticeSettings().qualities == [.minor7, .dominant7, .major7], "Defaults preserved")
        var newSettings = PracticeSettings()
        newSettings.qualities = [.minorMajor7, .dominantFlat9]
        let encoded = try! JSONEncoder().encode(newSettings)
        check((try! JSONDecoder().decode(PracticeSettings.self, from: encoded)).qualities == newSettings.qualities, "New settings round trip")
        let treble = Chord(literal: "Cmaj7").staffNotes!
        let bass = StaffClef.bass.writtenNotes(treble)
        check(bass.map(\.midi) == treble.map { $0.midi - 24 }, "Bass clef must move notes down exactly two octaves")
        check(bass.map(\.diatonicPosition) == treble.map { $0.diatonicPosition - 14 }, "Bass clef must preserve written pitch names")
        check(StaffClef.treble.writtenNotes(treble) == treble, "Treble clef keeps the standard register")
        for aliases in [["Cm", "Cmin", "C-", "C−"], ["Cm7", "Cmin7", "C-7", "C−7"], ["Cmaj7", "CM7", "CΔ7", "C△7"], ["Cm7b5", "Cm7♭5", "Cø7"], ["Cdim7", "C°7"], ["Csus4", "Csus"], ["CmMaj7", "Cmmaj7", "CmM7", "Cm(maj7)", "CminMaj7", "CmΔ7", "C−Δ7"], ["C7b9", "C7♭9", "C7(b9)", "C7(♭9)"]] {
            let reference = spell(aliases[0])
            for alias in aliases {
                check(spell(alias) == reference, "Alias \(alias)")
                check(Chord(literal: alias).formula == Chord(literal: aliases[0]).formula, "Alias formula \(alias)")
            }
        }
        for unsupported in ["", "H7", "c7", "C9", "Cmaj9", "C7/E", "Cdim", "Cadd9", "C7#5", "Cb#", "C###", "Dfoo", "Cmaj", "C♭♭dim7"] {
            check(Chord(literal: unsupported).staffNotes == nil, "Should reject \(unsupported)")
            if unsupported != "C♭♭dim7" { check(Chord(literal: unsupported).formula == nil, "No formula for \(unsupported)") }
        }
        print("Staff notation tests passed (24 root spellings × 10 qualities, aliases, edge cases).")
    }
}
