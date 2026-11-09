import Foundation

@main struct ChordAudioOptionsTests {
    static func check(_ condition: @autoclosure () -> Bool, _ message: String) {
        guard condition() else { fatalError(message) }
    }
    static func main() throws {
        var options = ChordAudioOptions()
        check(options.midiNotes(for: Chord(literal: "D7"), clef: .treble) == [62, 66, 69, 72], "D7 must sound D, F sharp, A, C")
        options.selectedTones = [.third, .seventh]
        check(options.midiNotes(for: Chord(literal: "D7"), clef: .treble) == [66, 72], "Guide tones must omit root and fifth")
        check(options.midiNotes(for: Chord(literal: "D7"), clef: .bass) == [42, 48], "Bass playback must match the bass staff")
        options.selectedTones = [.third]
        check(options.midiNotes(for: Chord(literal: "Csus4"), clef: .treble) == [65], "Suspended chords use the fourth in the second voice")
        options.selectedTones = [.ninth]
        check(options.midiNotes(for: Chord(literal: "C7b9"), clef: .treble) == [73], "The altered ninth must retain its octave")
        check(options.midiNotes(for: Chord(literal: "C7b9"), clef: .bass) == [49], "The bass ninth retains the same interval")
        check(options.midiNotes(for: Chord(literal: "C"), clef: .treble).isEmpty, "Absent tones must be omitted rather than substituted")
        check(options.midiNotes(for: Chord(literal: "C7/E"), clef: .treble).isEmpty, "Unsupported symbols must not invent audio")
        options.selectedTones = [.seventh]
        check(options.midiNotes(for: Chord(literal: "CmMaj7"), clef: .treble) == [71], "Minor major seventh must sound natural seventh")
        check(options.midiNotes(for: Chord(literal: "Cdim7"), clef: .treble) == [69], "Diminished seventh must sound double-flat seventh")
        options.selectedTones = [.seventh, .third, .third]
        check(options.validated().selectedTones == [.third, .seventh], "Saved selections are canonical and deduplicated")
        options.volume = .nan
        check(options.validated().volume == 0.5, "Invalid saved volume recovers safely")
        options.volume = 2
        check(options.validated().volume == 1, "Volume is capped")
        options.volume = -1
        check(options.validated().volume == 0, "Volume cannot be negative")
        options.selectedTones = []
        check(options.validated().selectedTones == ChordTone.allCases, "Empty saved selections recover safely")
        let legacy = try JSONDecoder().decode(PracticeSettings.self, from: Data(#"{"roots":[0,7],"qualities":["minor7","dominant7"],"interval":2,"displayMode":"staff"}"#.utf8))
        check(legacy.roots == [0, 7] && legacy.qualities == [.minor7, .dominant7] && legacy.interval == 2 && legacy.displayMode == .staff,
              "Adding sound must preserve existing practice preferences")
        check(legacy.audio.enabled && legacy.audio.instrument == .piano, "Older settings get playable sound defaults")
        var settings = PracticeSettings()
        settings.audio.enabled = false
        settings.audio.instrument = .guitar
        settings.audio.selectedTones = [.third, .seventh]
        settings.audio.volume = 0.3
        let restored = try JSONDecoder().decode(PracticeSettings.self, from: JSONEncoder().encode(settings))
        check(restored == settings, "Instrument, mute, tone choices and volume must survive saving")
        print("PASS: selected chord tones, register, altered ninths, suspended chords, unsupported symbols, settings migration and persistence.")
    }
}
