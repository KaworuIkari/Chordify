import Foundation

@main
struct CircleOfFifthsTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        if !condition() { fatalError(message) }
    }
    static func pitch(_ name: String) -> Int {
        guard let note = Chord(literal: name).staffNotes?.first else { fatalError("Invalid pitch \(name)") }
        return (note.midi % 12 + 12) % 12
    }
    static func main() {
        let keys = CircleOfFifths.keys
        check(keys.map(\.majorName) == ["C", "G", "D", "A", "E", "B", "F♯", "D♭", "A♭", "E♭", "B♭", "F"], "Key order")
        check(keys.map(\.id) == Array(0..<12), "Stable slot IDs")
        check(Set(keys.map { pitch($0.majorName) }).count == 12, "All pitch classes represented")
        let sharpOrder = ["F♯", "C♯", "G♯", "D♯", "A♯", "E♯", "B♯"]
        let flatOrder = ["B♭", "E♭", "A♭", "D♭", "G♭", "C♭", "F♭"]
        for (index, key) in keys.enumerated() {
            check((pitch(keys[(index + 1) % 12].majorName) - pitch(key.majorName) + 12) % 12 == 7, "Circle moves by fifths: \(key.majorName)")
        }
        for key in keys + [CircleOfFifths.gFlat] {
            check((pitch(key.relativeMinor) - pitch(key.majorName) + 12) % 12 == 9, "Relative minor: \(key.majorName)")
            check(key.signatureNotes == Array((key.signatureCount < 0 ? flatOrder : sharpOrder).prefix(abs(key.signatureCount))), "Signature: \(key.majorName)")
            let expectedDescription = key.signatureCount == 0 ? "No sharps or flats" : "\(abs(key.signatureCount)) \(key.signatureCount > 0 ? "sharp" : "flat")\(abs(key.signatureCount) == 1 ? "" : "s")"
            check(key.signatureDescription == expectedDescription, "Description: \(key.majorName)")
            let root = pitch(key.majorName)
            check(key.majorScale.map { (pitch($0) - root + 12) % 12 } == [0, 2, 4, 5, 7, 9, 11], "Scale pitches: \(key.majorName)")
            check(key.majorScale[0] == key.majorName && key.majorScale[5] == key.relativeMinor, "Scale tonic and relative minor")
            check(key.seventhChords.count == 7, "Seven chords")
            for degree in 0..<7 {
                guard let notes = Chord(literal: key.seventhChords[degree]).staffNotes else { fatalError("Unrecognized \(key.seventhChords[degree])") }
                let expected = [0, 2, 4, 6].map { key.majorScale[(degree + $0) % 7] }
                let actual = notes.map { $0.letter + ($0.accidental == -1 ? "♭" : $0.accidental == 1 ? "♯" : $0.accidental == -2 ? "♭♭" : $0.accidental == 2 ? "♯♯" : "") }
                check(actual == expected, "Chord spelling \(key.seventhChords[degree]): \(actual) != \(expected)")
            }
        }
        check(CircleOfFifths.keys[6].majorScale == ["F♯", "G♯", "A♯", "B", "C♯", "D♯", "E♯"], "F sharp spelling")
        check(CircleOfFifths.gFlat.majorScale == ["G♭", "A♭", "B♭", "C♭", "D♭", "E♭", "F"], "G flat spelling")
        check(CircleOfFifths.gFlat.relativeMinor == "E♭" && CircleOfFifths.gFlat.signatureCount == -6, "G flat relative minor and signature")
        check(CircleOfFifths.key(at: -1) == keys[11], "Negative index wraps")
        check(CircleOfFifths.key(at: Int.min) == keys[((Int.min % 12) + 12) % 12], "Minimum integer wraps")
        check(CircleOfFifths.key(at: 18, preferFlats: true) == CircleOfFifths.gFlat, "Flat alternative wraps")
        check(CircleOfFifths.key(at: 18) == keys[6], "Sharp default wraps")
        print("Circle of fifths tests passed: 12 keys plus G♭, scales, signatures and 91 seventh chords.")
    }
}
