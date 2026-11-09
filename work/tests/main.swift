import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
    guard condition() else { fatalError(message) }
}

let defaultPool = PracticeSettings().chords
check(defaultPool.count == 36, "Default pool must contain all 12 roots and 3 seventh types")
check(defaultPool.contains(Chord(root: "B", accidental: "♭", suffix: "Δ7")), "Flat jazz notation is supported")
var deck = ChordDeck(chords: defaultPool)
var previous: Chord?
for _ in 0..<200 {
    var cycle = Set<Chord>()
    for _ in 0..<defaultPool.count {
        let chord = deck.next()!
        check(chord != previous, "Adjacent chords must not repeat, including deck boundaries")
        check(cycle.insert(chord).inserted, "Every chord must appear once per cycle")
        previous = chord
    }
    check(cycle == Set(defaultPool), "A cycle must cover the entire selected pool")
}
var single = ChordDeck(chords: [Chord(root: "C")])
for _ in 0..<100 { check(single.next()?.name == "C", "Single chord pools must remain usable") }
var empty = ChordDeck(chords: [])
check(empty.next() == nil, "Empty deck is safe")

var custom = PracticeSettings()
custom.useCustom = true
custom.customText = " Dm7, G7\n CΔ7 ; B♭7, Dm7, \nF♯m7 "
check(custom.chords.map(\.name) == ["Dm7", "G7", "CΔ7", "B♭7", "F♯m7"], "Custom list must trim, deduplicate, and preserve notation")
let data = try JSONEncoder().encode(custom)
let restored = try JSONDecoder().decode(PracticeSettings.self, from: data)
check(restored == custom, "Settings must survive a save and reload")
var invalid = PracticeSettings()
invalid.roots = [-1, 90]
invalid.interval = .infinity
check(!invalid.validated().chords.isEmpty, "Invalid saved preferences must recover to a usable pool")
invalid = PracticeSettings()
invalid.interval = -4
check(invalid.validated().interval == 0.5, "Very short intervals are clamped")
invalid.interval = 999
check(invalid.validated().interval == 300, "Very long intervals are clamped")

var clock = PracticeClock(duration: 4)
clock.start(at: 100)
check(!clock.tick(at: 101.5) && clock.remaining == 2.5, "Countdown should track elapsed time")
clock.pause(at: 102)
check(!clock.isRunning && clock.remaining == 2, "Pausing preserves the remaining interval")
check(!clock.tick(at: 500) && clock.remaining == 2, "Paused time must not elapse")
clock.start(at: 500)
check(!clock.tick(at: 501.9), "Resume should preserve the partial interval")
check(clock.tick(at: 502) && clock.remaining == 4, "Elapsed interval advances once and resets")
check(!clock.tick(at: 502), "A repeated timer delivery must not advance twice")
check(clock.tick(at: 900), "A late timer delivery advances once")
check(!clock.tick(at: 900.01), "Late delivery must not rapidly catch up through missed chords")
clock.reset(duration: 8, at: 901)
check(clock.remaining == 8 && !clock.tick(at: 905), "Manual next restarts a full interval")
clock.pause(at: 906)
check(clock.remaining == 3, "Reset deadline is correct")
print("PASS: 7,200 randomized draws; deck fairness and repeat protection; custom chord parsing; settings persistence and recovery; timer pause, resume, reset, and delayed delivery.")
