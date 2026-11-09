import Foundation

struct CircleKey: Identifiable, Equatable {
    let id: Int
    let majorName: String
    let relativeMinor: String
    let signatureCount: Int
    let signatureNotes: [String]
    let majorScale: [String]
    let seventhChords: [String]

    var signatureDescription: String {
        if signatureCount == 0 { return "No sharps or flats" }
        let count = abs(signatureCount)
        let kind = signatureCount > 0 ? "sharp" : "flat"
        return "\(count) \(kind)\(count == 1 ? "" : "s")"
    }
}

enum CircleOfFifths {
    private static let sharpOrder = ["F♯", "C♯", "G♯", "D♯", "A♯", "E♯", "B♯"]
    private static let flatOrder = ["B♭", "E♭", "A♭", "D♭", "G♭", "C♭", "F♭"]
    private static let letters = ["C", "D", "E", "F", "G", "A", "B"]

    private static func makeKey(id: Int, root: String, signatureCount: Int) -> CircleKey {
        let signature = Array((signatureCount < 0 ? flatOrder : sharpOrder).prefix(abs(signatureCount)))
        let rootIndex = letters.firstIndex(of: String(root.prefix(1)))!
        let scale = (0..<7).map { offset -> String in
            let letter = letters[(rootIndex + offset) % 7]
            return signature.first { $0.hasPrefix(letter) } ?? letter
        }
        let suffixes = ["Δ7", "−7", "−7", "Δ7", "7", "−7", "ø7"]
        return CircleKey(id: id, majorName: root, relativeMinor: scale[5],
                         signatureCount: signatureCount, signatureNotes: signature,
                         majorScale: scale, seventhChords: zip(scale, suffixes).map(+))
    }

    static let keys: [CircleKey] = [
        makeKey(id: 0, root: "C", signatureCount: 0),
        makeKey(id: 1, root: "G", signatureCount: 1),
        makeKey(id: 2, root: "D", signatureCount: 2),
        makeKey(id: 3, root: "A", signatureCount: 3),
        makeKey(id: 4, root: "E", signatureCount: 4),
        makeKey(id: 5, root: "B", signatureCount: 5),
        makeKey(id: 6, root: "F♯", signatureCount: 6),
        makeKey(id: 7, root: "D♭", signatureCount: -5),
        makeKey(id: 8, root: "A♭", signatureCount: -4),
        makeKey(id: 9, root: "E♭", signatureCount: -3),
        makeKey(id: 10, root: "B♭", signatureCount: -2),
        makeKey(id: 11, root: "F", signatureCount: -1)
    ]
    static let gFlat = makeKey(id: 6, root: "G♭", signatureCount: -6)

    static func key(at index: Int, preferFlats: Bool = false) -> CircleKey {
        let slot = ((index % 12) + 12) % 12
        return slot == 6 && preferFlats ? gFlat : keys[slot]
    }
}
