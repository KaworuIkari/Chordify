import Foundation
import AVFoundation

@MainActor final class FakeMetronomePlayer: MetronomeSoundPlaying {
    var starts: [MetronomeConfiguration] = []
    var stopCount = 0
    var volumes: [Double] = []
    var fail = false
    func start(_ configuration: MetronomeConfiguration) throws {
        if fail { throw NSError(domain: "test", code: 1) }
        starts.append(configuration)
    }
    func stop() { stopCount += 1 }
    func setVolume(_ volume: Double) { volumes.append(volume) }
}

@main struct MetronomeTests {
    static func check(_ value: @autoclosure () -> Bool, _ message: String) { if !value() { fatalError(message) } }
    @MainActor static func main() {
        let suite = "MetronomeTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        var time = 100.0
        let fake = FakeMetronomePlayer()
        let model = MetronomeModel(defaults: defaults, now: { time }, automaticTimer: false, player: fake)
        check(!model.running && model.tempo == 100 && model.beatsPerBar == 4, "Defaults")
        model.setTempo(-5); check(model.tempo == 30, "Minimum tempo")
        model.setTempo(500); check(model.tempo == 300, "Maximum tempo")
        model.setBeatsPerBar(15); check(model.beatsPerBar == 8, "Maximum meter")
        model.setBeatsPerBar(0); check(model.beatsPerBar == 1, "Minimum meter")
        model.setAccentFirstBeat(false); model.setVolume(4)
        let restored = MetronomeModel(defaults: defaults, automaticTimer: false, player: FakeMetronomePlayer())
        check(restored.tempo == 300 && restored.beatsPerBar == 1 && !restored.accentFirstBeat && restored.volume == 1 && !restored.running, "Saved settings, stopped on launch")
        model.setTempo(100); model.setBeatsPerBar(4); model.toggle()
        check(model.running && fake.starts.count == 1 && model.currentBeat == 0, "Start")
        time += 0.61; model.tick(); check(model.currentBeat == 1, "Visual beat")
        time += 1.8; model.tick(); check(model.currentBeat == 0, "Visual bar wrap")
        model.setVolume(0.2); check(fake.starts.count == 1 && fake.volumes.last == 0.2, "Volume does not restart")
        model.setTempo(120); check(fake.starts.count == 2 && model.currentBeat == 0, "Tempo restarts at downbeat")
        model.toggle(); check(!model.running && model.currentBeat == 0, "Stop")
        let tapModel = MetronomeModel(defaults: nil, now: { time }, automaticTimer: false, player: fake)
        tapModel.tap(); time += 0.1; tapModel.tap(); time += 0.4; tapModel.tap()
        check(tapModel.tempo == 120, "Debounce and tap tempo")
        time += 3; tapModel.tap(); check(tapModel.tempo == 120, "Long gap resets tap history")
        time += 1; tapModel.tap(); check(tapModel.tempo == 60, "New tap sequence")
        let failing = FakeMetronomePlayer(); failing.fail = true
        let errorModel = MetronomeModel(defaults: nil, automaticTimer: false, player: failing)
        errorModel.toggle(); check(!errorModel.running && errorModel.errorMessage != nil, "Friendly start error")
        for tempo in [37, 127, 299] {
            for beats in [1, 3, 4, 7, 8] {
                let buffer = MetronomeBufferRenderer.render(tempo: tempo, beats: beats, accent: true)
                let frames = Int(buffer.frameLength)
                check(frames == Int((Double(beats) * 44_100 * 60 / Double(tempo)).rounded()), "Bar duration")
                let samples = buffer.floatChannelData![0]
                for index in 0..<frames { check(samples[index].isFinite && abs(samples[index]) <= 1, "Finite bounded signal") }
                for beat in 0..<beats {
                    let start = Int((Double(beat) * 44_100 * 60 / Double(tempo)).rounded())
                    let peak = (start..<min(start + 1000, frames)).map { abs(samples[$0]) }.max()!
                    check(peak > 0.1, "Beat onset")
                    if start > 20 { check((start-20..<start).allSatisfy { abs(samples[$0]) < 0.00001 }, "No early click") }
                }
            }
        }
        let accentBuffer = MetronomeBufferRenderer.render(tempo: 100, beats: 4, accent: true)
        let accented = accentBuffer.floatChannelData![0]
        let plainBuffer = MetronomeBufferRenderer.render(tempo: 100, beats: 4, accent: false)
        let plain = plainBuffer.floatChannelData![0]
        check((0..<500).map { abs(accented[$0]) }.max()! > (0..<500).map { abs(plain[$0]) }.max()!, "Accent louder")
        print("Metronome tests passed: persistence, timing, controls, tap, errors and offline bar buffers.")
    }
}
