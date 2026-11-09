import Foundation

@MainActor final class RecordingSoundPlayer: ChordSoundPlaying {
    struct Event {
        let notes: [UInt8]
        let instrument: ChordInstrument
        let volume: Double
        let duration: Double
    }
    var events: [Event] = []
    var stopCount = 0
    var volumes: [Double] = []
    var fail = false
    struct TestError: LocalizedError {
        var errorDescription: String? { "Test audio output unavailable." }
    }
    func play(notes: [UInt8], instrument: ChordInstrument, volume: Double, duration: Double) throws {
        if fail { throw TestError() }
        events.append(Event(notes: notes, instrument: instrument, volume: volume, duration: duration))
    }
    func stop() { stopCount += 1 }
    func setVolume(_ volume: Double) { volumes.append(volume) }
}

@main struct ChordAudioModelTests {
    @MainActor static func main() {
        func check(_ condition: @autoclosure () -> Bool, _ message: String) {
            guard condition() else { fatalError(message) }
        }
        var settings = PracticeSettings()
        settings.useCustom = true
        settings.customText = "C7, Dm7"
        settings.interval = 2
        settings.sessionMinutes = 0.5
        let player = RecordingSoundPlayer()
        var now = 0.0
        let model = PracticeModel(settingsOverride: settings, defaults: nil, now: { now }, automaticTimer: false, soundPlayer: player)
        check(player.events.isEmpty, "Opening the app must remain silent")
        model.toggle()
        check(player.events.count == 1 && player.events.last!.notes == settings.audio.midiNotes(for: model.chord, clef: .treble),
              "Start must play exactly the displayed chord")
        now = 1; model.tick()
        check(player.events.count == 1, "Display refreshes must not retrigger the chord")
        now = 2; model.tick()
        check(player.events.count == 2 && player.events.last!.notes == settings.audio.midiNotes(for: model.chord, clef: .treble),
              "Each new chord must trigger the matching sound once")
        now = 2.5; model.pause()
        let pausedSession = model.sessionRemaining
        let pausedInterval = model.remaining
        let stopped = player.stopCount
        check(stopped > 0 && !model.running, "Pause must silence playback")
        model.replayChord()
        check(player.events.count == 3 && model.sessionRemaining == pausedSession && model.remaining == pausedInterval && !model.running,
              "Replay must work while paused without advancing either timer")
        var audio = model.settings.audio
        audio.enabled = false
        model.setAudioOptions(audio)
        check(player.stopCount > stopped, "Disabling automatic sound must silence active notes")
        model.toggle()
        let mutedEvents = player.events.count
        now = 4.1; model.tick(); model.next()
        check(player.events.count == mutedEvents, "Muted practice and Next must remain silent")
        model.replayChord()
        check(player.events.count == mutedEvents + 1, "Manual Replay must still work with automatic sound off")
        audio.enabled = true
        audio.instrument = .guitar
        audio.selectedTones = [.third, .seventh]
        model.setAudioOptions(audio)
        check(player.events.last!.instrument == .guitar && player.events.last!.notes == audio.midiNotes(for: model.chord, clef: .treble),
              "Changing instruments and selected roles while practicing must update the current sound")
        let beforeVolume = player.events.count
        audio.volume = 0.25
        model.setAudioOptions(audio)
        check(player.events.count == beforeVolume && player.volumes.last == 0.25, "Volume changes must not retrigger notes")
        model.setClef(.bass)
        check(player.events.last!.notes == audio.midiNotes(for: model.chord, clef: .bass), "Audio register must follow the staff")
        let beforeDisplay = player.events.count
        model.setDisplayMode(.staff)
        check(player.events.count == beforeDisplay, "Hiding the answer must not retrigger sound")
        model.pause()
        let saved = model.settings
        var preview = ChordAudioOptions()
        preview.enabled = false
        preview.instrument = .strings
        model.previewAudio(preview, clef: .treble)
        check(model.settings == saved && player.events.last!.instrument == .strings && !model.running,
              "Settings preview must not change saved preferences or start a session")
        model.stopAudio()
        model.toggle()
        let beforeFinish = player.events.count
        now = 100; model.tick()
        check(model.completed && !model.running && player.events.count == beforeFinish, "Expiry must stop sound without playing an extra chord")
        player.fail = true
        model.replayChord()
        check(model.audioError == "Test audio output unavailable.", "Playback errors must be shown without crashing")
        player.fail = false
        model.replayChord()
        check(model.audioError == nil, "Replay can recover after an audio error")
        print("PASS: sound/display synchronization, mute, replay, tone and instrument changes, register, pause/end cleanup, preview and error recovery.")
    }
}
