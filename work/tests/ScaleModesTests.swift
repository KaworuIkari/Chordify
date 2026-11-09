import Foundation

@main struct ScaleModesTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) { if !condition() { fatalError(message) } }
    static func pitch(_ name: String) -> Int {
        guard let note = Chord(literal: name).staffNotes?.first else { fatalError("Invalid note \(name)") }
        return (note.midi % 12 + 12) % 12
    }
    static func main() {
        let keys = CircleOfFifths.keys + [CircleOfFifths.gFlat]
        let expectedRomans = [
            ["I", "ii", "iii", "IV", "V", "vi", "viiø"],
            ["i", "ii", "♭III", "IV", "v", "viø", "♭VII"],
            ["i", "♭II", "♭III", "iv", "vø", "♭VI", "♭vii"],
            ["I", "II", "iii", "♯ivø", "V", "vi", "vii"],
            ["I", "ii", "iiiø", "IV", "v", "vi", "♭VII"],
            ["i", "iiø", "♭III", "iv", "v", "♭VI", "♭VII"],
            ["iø", "♭II", "♭iii", "iv", "♭V", "♭VI", "♭vii"]
        ]
        for key in keys {
            for (modeIndex, mode) in ScaleMode.allCases.enumerated() {
                guard let scale = ModalScale(tonic: key.majorName, mode: mode) else { fatalError("Missing \(key.majorName) \(mode)") }
                check(scale.notes[0] == key.majorName && scale.tonic == key.majorName, "Fixed tonic")
                check(Set(scale.notes.map { $0.first! }).count == 7, "Seven different letters")
                let root = pitch(scale.tonic)
                check(scale.notes.map { (pitch($0) - root + 12) % 12 } == mode.semitoneIntervals, "Scale intervals \(key.majorName) \(mode)")
                check(scale.romanDegrees == expectedRomans[modeIndex], "Roman degrees \(mode)")
                guard let parent = ModalScale(tonic: scale.parentMajor, mode: .ionian) else { fatalError("Missing parent \(scale.parentMajor)") }
                check(Set(parent.notes) == Set(scale.notes), "Parent major pitch spelling")
                for degree in 0..<7 {
                    guard let chord = Chord(literal: scale.seventhChords[degree]).staffNotes else { fatalError("Unsupported chord \(scale.seventhChords[degree])") }
                    let spelled = chord.map { $0.letter + String(repeating: $0.accidental < 0 ? "♭" : "♯", count: abs($0.accidental)) }
                    check(spelled == [0,2,4,6].map { scale.notes[(degree + $0) % 7] }, "Chord spelling \(scale.seventhChords[degree])")
                }
            }
        }
        func notes(_ tonic: String, _ mode: ScaleMode) -> [String] { ModalScale(tonic: tonic, mode: mode)!.notes }
        check(notes("F", .dorian) == ["F","G","A♭","B♭","C","D","E♭"], "F dorian")
        check(notes("C", .dorian) == ["C","D","E♭","F","G","A","B♭"], "C dorian")
        check(notes("D", .dorian) == ["D","E","F","G","A","B","C"], "D dorian")
        check(notes("C", .mixolydian) == ["C","D","E","F","G","A","B♭"], "C mixolydian")
        check(notes("G", .mixolydian) == ["G","A","B","C","D","E","F"], "G mixolydian")
        check(notes("F", .lydian) == ["F","G","A","B","C","D","E"], "F lydian")
        check(notes("A", .aeolian) == ["A","B","C","D","E","F","G"], "A natural minor")
        check(notes("B", .locrian) == ["B","C","D","E","F","G","A"], "B locrian")
        check(ModalScale(tonic: "D", mode: .dorian)!.parentMajor == "C", "D dorian parent")
        check(ModalScale(tonic: "F", mode: .dorian)!.parentMajor == "E♭", "F dorian parent")
        check(ModalScale(tonic: "F", mode: .dorian)!.signatureDescription == "3 flats", "F dorian signature")
        check(ModalScale(tonic: "F", mode: .mixolydian)!.signatureDescription == "2 flats", "F mixolydian signature")
        let theoretical = ModalScale(tonic: "Gb", mode: .locrian)!
        check(theoretical.signatureDescription == "Theoretical key spelling" && theoretical.notes.contains("A♭♭") && theoretical.alteredNotes.contains("A♭♭"), "Theoretical spelling")
        check(ScaleMode.dorian.formula == "1 2 ♭3 4 5 6 ♭7", "Mode formula")
        for invalid in ["", "H", "c", "C#b", "C7", "C♭♭♭"] { check(ModalScale(tonic: invalid, mode: .ionian) == nil, "Invalid tonic \(invalid)") }
        print("Scale mode tests passed: 13 tonics × 7 modes, 637 harmonized seventh chords.")
    }
}
