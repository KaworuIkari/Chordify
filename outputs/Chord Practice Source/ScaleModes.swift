import Foundation

enum ScaleMode: String, Codable, CaseIterable, Identifiable {
    case ionian, dorian, phrygian, lydian, mixolydian, aeolian, locrian
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .ionian: return "Major (Ionian)"
        case .dorian: return "Dorian"
        case .phrygian: return "Phrygian"
        case .lydian: return "Lydian"
        case .mixolydian: return "Mixolydian"
        case .aeolian: return "Natural minor (Aeolian)"
        case .locrian: return "Locrian"
        }
    }
    var shortName: String {
        switch self {
        case .ionian: return "Major"
        case .aeolian: return "Natural minor"
        default: return displayName
        }
    }
    var semitoneIntervals: [Int] {
        switch self {
        case .ionian: return [0, 2, 4, 5, 7, 9, 11]
        case .dorian: return [0, 2, 3, 5, 7, 9, 10]
        case .phrygian: return [0, 1, 3, 5, 7, 8, 10]
        case .lydian: return [0, 2, 4, 6, 7, 9, 11]
        case .mixolydian: return [0, 2, 4, 5, 7, 9, 10]
        case .aeolian: return [0, 2, 3, 5, 7, 8, 10]
        case .locrian: return [0, 1, 3, 5, 6, 8, 10]
        }
    }
    var formula: String {
        let major = ScaleMode.ionian.semitoneIntervals
        return zip(semitoneIntervals, major).enumerated().map { index, pair in
            (pair.0 < pair.1 ? "♭" : pair.0 > pair.1 ? "♯" : "") + String(index + 1)
        }.joined(separator: " ")
    }
}

struct ModalScale {
    let tonic: String
    let mode: ScaleMode
    let notes: [String]
    let seventhChords: [String]
    let romanDegrees: [String]
    let parentMajor: String
    let alteredNotes: [String]
    let signatureDescription: String

    init?(tonic input: String, mode: ScaleMode) {
        let text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        let letters = ["C", "D", "E", "F", "G", "A", "B"]
        let naturals = [0, 2, 4, 5, 7, 9, 11]
        guard let first = text.first, let rootIndex = letters.firstIndex(of: String(first)) else { return nil }
        let accidentalText = String(text.dropFirst())
        let accidental: Int
        switch accidentalText {
        case "": accidental = 0
        case "♯", "#": accidental = 1
        case "♭", "b": accidental = -1
        case "♯♯", "##": accidental = 2
        case "♭♭", "bb": accidental = -2
        default: return nil
        }
        func accidentalSymbol(_ count: Int) -> String {
            String(repeating: count < 0 ? "♭" : "♯", count: abs(count))
        }
        let rootPitch = naturals[rootIndex] + accidental
        var scale: [String] = []
        for degree in 0..<7 {
            let position = rootIndex + degree
            let index = position % 7
            let naturalPitch = naturals[index] + 12 * (position / 7)
            let alteration = rootPitch + mode.semitoneIntervals[degree] - naturalPitch
            guard (-2...2).contains(alteration) else { return nil }
            scale.append(letters[index] + accidentalSymbol(alteration))
        }
        self.tonic = scale[0]
        self.mode = mode
        self.notes = scale
        let modeIndex = ScaleMode.allCases.firstIndex(of: mode)!
        parentMajor = scale[(7 - modeIndex) % 7]
        let roman = ["I", "II", "III", "IV", "V", "VI", "VII"]
        var chords: [String] = []
        var numerals: [String] = []
        for degree in 0..<7 {
            func distance(_ offset: Int) -> Int {
                let absolute = degree + offset
                return mode.semitoneIntervals[absolute % 7] + (absolute / 7) * 12 - mode.semitoneIntervals[degree]
            }
            let intervals = [distance(2), distance(4), distance(6)]
            let suffix: String
            let numeral: String
            switch intervals {
            case [4, 7, 11]: suffix = "Δ7"; numeral = roman[degree]
            case [3, 7, 10]: suffix = "−7"; numeral = roman[degree].lowercased()
            case [4, 7, 10]: suffix = "7"; numeral = roman[degree]
            case [3, 6, 10]: suffix = "ø7"; numeral = roman[degree].lowercased() + "ø"
            default: return nil
            }
            chords.append(scale[degree] + suffix)
            let difference = mode.semitoneIntervals[degree] - ScaleMode.ionian.semitoneIntervals[degree]
            numerals.append(accidentalSymbol(difference) + numeral)
        }
        seventhChords = chords
        romanDegrees = numerals
        let sharps = ["F♯", "C♯", "G♯", "D♯", "A♯", "E♯", "B♯"]
        let flats = ["B♭", "E♭", "A♭", "D♭", "G♭", "C♭", "F♭"]
        let alterations = scale.filter { $0.count > 1 }
        let sharpPrefix = Array(sharps.prefix(alterations.count))
        let flatPrefix = Array(flats.prefix(alterations.count))
        if alterations.isEmpty {
            alteredNotes = []; signatureDescription = "No sharps or flats"
        } else if Set(alterations) == Set(sharpPrefix) {
            alteredNotes = sharpPrefix
            signatureDescription = "\(alterations.count) sharp\(alterations.count == 1 ? "" : "s")"
        } else if Set(alterations) == Set(flatPrefix) {
            alteredNotes = flatPrefix
            signatureDescription = "\(alterations.count) flat\(alterations.count == 1 ? "" : "s")"
        } else {
            // Theoretical signatures can include double accidentals; preserve their spelling.
            let order = alterations.contains(where: { $0.contains("♭") }) ? flats : sharps
            alteredNotes = alterations.sorted { left, right in
                let leftIndex = order.firstIndex { $0.first == left.first } ?? 7
                let rightIndex = order.firstIndex { $0.first == right.first } ?? 7
                return leftIndex < rightIndex
            }
            signatureDescription = "Theoretical key spelling"
        }
    }
}
