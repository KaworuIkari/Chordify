import Foundation

@main struct SessionTests {
    @MainActor static func main() throws {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }

        var settings = PracticeSettings()
        settings.audio.enabled = false
        settings.useCustom = true
        settings.customText = "C7, D−7"
        settings.interval = 4
        settings.sessionMinutes = 0.5
        var now = 0.0
        let model = PracticeModel(settingsOverride: settings, defaults: nil, now: { now }, automaticTimer: false)
        model.toggle()
        let first = model.chord
        now = 4; model.tick()
        check(model.chord != first, "The second selected chord must appear")
        now = 8; model.tick()
        check(model.chord == first && model.displayed == 3, "The selected pool must repeat within the session")
        let currentChord = model.chord
        let sessionLeft = model.sessionRemaining
        let intervalLeft = model.remaining
        model.setDisplayMode(.staff)
        model.setClef(.bass)
        check(model.running && model.chord == currentChord && model.sessionRemaining == sessionLeft && model.remaining == intervalLeft,
              "Switching notation or clef must preserve the chord and both countdowns")
        check(model.settings.displayMode == .staff && model.settings.staffClef == .bass, "Display controls must update settings")
        now = 10; model.pause()
        check(model.sessionRemaining == 20 && !model.running, "Pause must freeze both countdowns")
        now = 100; model.tick()
        check(model.sessionRemaining == 20, "Breaks must not consume practice time")
        model.toggle()
        now = 101; model.next()
        check(model.sessionRemaining == 19 && model.running, "Next must not restart or pause the session countdown")
        now = 119; model.tick()
        check(model.running && model.sessionRemaining == 1, "The session remains active until its deadline")
        let count = model.displayed
        now = 120; model.tick()
        check(!model.running && model.completed && model.sessionRemaining == 0, "The session must stop automatically")
        check(model.displayed == count, "No extra chord may appear when the session ends")
        now = 200; model.tick(); model.next()
        check(model.completed && model.displayed == count, "A completed session must stay stopped")
        model.toggle()
        check(model.running && model.sessionRemaining == 30 && model.remaining == 4, "Practice again must reset both clocks")

        settings.sessionMinutes = 2
        model.apply(settings)
        check(!model.running && model.sessionRemaining == 120 && !model.completed, "Saving a new duration must prepare a fresh session")
        settings.unlimitedSession = true
        model.apply(settings); model.toggle()
        now = 10_000; model.tick()
        check(model.running && model.sessionRemaining == nil && !model.completed, "Unlimited practice must keep cycling")

        var legacy = try JSONSerialization.jsonObject(with: JSONEncoder().encode(settings)) as! [String: Any]
        legacy.removeValue(forKey: "sessionMinutes")
        legacy.removeValue(forKey: "unlimitedSession")
        legacy.removeValue(forKey: "displayMode")
        legacy.removeValue(forKey: "staffClef")
        let upgraded = try JSONDecoder().decode(PracticeSettings.self, from: JSONSerialization.data(withJSONObject: legacy))
        check(upgraded.customText == settings.customText && upgraded.interval == settings.interval && upgraded.sessionMinutes == 5,
              "Upgrading must preserve existing chords and interval, and add a five-minute session")
        check(upgraded.displayMode == .chordName && upgraded.staffClef == .treble, "Old preferences must get safe display defaults")
        settings.displayMode = .both
        settings.staffClef = .bass
        let reloaded = try JSONDecoder().decode(PracticeSettings.self, from: JSONEncoder().encode(settings))
        check(reloaded.unlimitedSession && reloaded.sessionMinutes == 2, "Session settings must survive saving")
        check(reloaded.displayMode == .both && reloaded.staffClef == .bass, "Staff preferences must survive saving")
        print("PASS: repeated chords; session expiry; pause/resume; Next preserves session duration; restart; new settings; unlimited practice; existing-settings migration.")
    }
}
