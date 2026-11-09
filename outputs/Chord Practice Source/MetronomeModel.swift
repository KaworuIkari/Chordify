import Foundation
import Combine
import AVFoundation

struct MetronomeConfiguration: Equatable {
    let tempo: Int
    let beatsPerBar: Int
    let accentFirstBeat: Bool
    let volume: Double
}

@MainActor protocol MetronomeSoundPlaying: AnyObject {
    func start(_ configuration: MetronomeConfiguration) throws
    func stop()
    func setVolume(_ volume: Double)
}

/// Creates one sample-accurate looping bar before playback, never on an audio callback.
enum MetronomeBufferRenderer {
    static let sampleRate = 44_100.0
    static func framesPerBar(tempo: Int, beats: Int) -> Int {
        Int((Double(beats) * sampleRate * 60 / Double(tempo)).rounded())
    }
    static func beatFrame(_ beat: Int, tempo: Int) -> Int {
        Int((Double(beat) * sampleRate * 60 / Double(tempo)).rounded())
    }
    static func render(tempo: Int, beats: Int, accent: Bool) -> AVAudioPCMBuffer {
        let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1)!
        let frames = framesPerBar(tempo: tempo, beats: beats)
        let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(frames))!
        buffer.frameLength = AVAudioFrameCount(frames)
        let data = buffer.floatChannelData![0]
        data.initialize(repeating: 0, count: frames)
        let clickFrames = Int(sampleRate * 0.03)
        for beat in 0..<beats {
            let start = beatFrame(beat, tempo: tempo)
            let emphasis = beat == 0 && accent
            let frequency = emphasis ? 1600.0 : 1000.0
            let amplitude = emphasis ? 0.85 : 0.55
            for sample in 0..<min(clickFrames, frames - start) {
                let t = Double(sample) / sampleRate
                let envelope = exp(-t * 145) * min(1, t * 2000)
                data[start + sample] += Float(amplitude * envelope * sin(2 * .pi * frequency * t))
            }
        }
        return buffer
    }
}

@MainActor final class MetronomeAudioPlayer: MetronomeSoundPlaying {
    private var engine: AVAudioEngine?
    private var node: AVAudioPlayerNode?
    func start(_ configuration: MetronomeConfiguration) throws {
        let audioEngine: AVAudioEngine
        let player: AVAudioPlayerNode
        if let engine, let node { audioEngine = engine; player = node }
        else {
            audioEngine = AVAudioEngine()
            player = AVAudioPlayerNode()
            audioEngine.attach(player)
            let format = AVAudioFormat(standardFormatWithSampleRate: MetronomeBufferRenderer.sampleRate, channels: 1)!
            audioEngine.connect(player, to: audioEngine.mainMixerNode, format: format)
            engine = audioEngine
            node = player
        }
        player.stop()
        player.volume = Float(configuration.volume)
        let buffer = MetronomeBufferRenderer.render(tempo: configuration.tempo, beats: configuration.beatsPerBar, accent: configuration.accentFirstBeat)
        player.scheduleBuffer(buffer, at: nil, options: .loops)
        if !audioEngine.isRunning { try audioEngine.start() }
        player.play()
    }
    func stop() { node?.stop(); engine?.stop() }
    func setVolume(_ volume: Double) { node?.volume = Float(volume) }
}

@MainActor final class MetronomeModel: ObservableObject {
    @Published private(set) var tempo = 100
    @Published private(set) var beatsPerBar = 4
    @Published private(set) var accentFirstBeat = true
    @Published private(set) var volume = 0.5
    @Published private(set) var running = false
    @Published private(set) var currentBeat = 0
    @Published private(set) var errorMessage: String?

    private struct Settings: Codable {
        var tempo: Int
        var beatsPerBar: Int
        var accentFirstBeat: Bool
        var volume: Double
    }
    private let defaults: UserDefaults?
    private let now: () -> Double
    private let automaticTimer: Bool
    private let player: any MetronomeSoundPlaying
    private var timer: Timer?
    private var barStart = 0.0
    private var taps: [Double] = []
    private let key = "metronome.settings.v1"

    init(defaults: UserDefaults? = .standard, now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime }, automaticTimer: Bool = true, player: (any MetronomeSoundPlaying)? = nil) {
        self.defaults = defaults
        self.now = now
        self.automaticTimer = automaticTimer
        self.player = player ?? MetronomeAudioPlayer()
        if let data = defaults?.data(forKey: key), let saved = try? JSONDecoder().decode(Settings.self, from: data) {
            tempo = min(300, max(30, saved.tempo))
            beatsPerBar = min(8, max(1, saved.beatsPerBar))
            accentFirstBeat = saved.accentFirstBeat
            volume = saved.volume.isFinite ? min(1, max(0, saved.volume)) : 0.5
        }
    }
    private var configuration: MetronomeConfiguration {
        .init(tempo: tempo, beatsPerBar: beatsPerBar, accentFirstBeat: accentFirstBeat, volume: volume)
    }
    private func save() {
        let settings = Settings(tempo: tempo, beatsPerBar: beatsPerBar, accentFirstBeat: accentFirstBeat, volume: volume)
        if let data = try? JSONEncoder().encode(settings) { defaults?.set(data, forKey: key) }
    }
    private func restartIfRunning() {
        guard running else { return }
        do {
            try player.start(configuration)
            barStart = now()
            currentBeat = 0
            errorMessage = nil
        } catch {
            stop()
            errorMessage = "Unable to start the metronome. Check your audio output and try again."
        }
    }
    func setTempo(_ value: Int) {
        let value = min(300, max(30, value))
        guard tempo != value else { return }
        tempo = value; save(); restartIfRunning()
    }
    func setBeatsPerBar(_ value: Int) {
        let value = min(8, max(1, value))
        guard beatsPerBar != value else { return }
        beatsPerBar = value; save(); restartIfRunning()
    }
    func setAccentFirstBeat(_ value: Bool) {
        guard accentFirstBeat != value else { return }
        accentFirstBeat = value; save(); restartIfRunning()
    }
    func setVolume(_ value: Double) {
        let value = value.isFinite ? min(1, max(0, value)) : 0.5
        guard volume != value else { return }
        volume = value; save(); player.setVolume(value)
    }
    func toggle() {
        if running { stop(); return }
        do {
            try player.start(configuration)
            barStart = now(); currentBeat = 0; running = true; errorMessage = nil
            if automaticTimer {
                timer?.invalidate()
                timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30, repeats: true) { [weak self] _ in
                    Task { @MainActor [weak self] in self?.tick() }
                }
            }
        } catch { player.stop(); errorMessage = "Unable to start the metronome. Check your audio output and try again." }
    }
    func stop() {
        timer?.invalidate(); timer = nil
        player.stop(); running = false; currentBeat = 0
    }
    func tick() {
        guard running else { return }
        let elapsed = max(0, now() - barStart)
        let sampleRate = MetronomeBufferRenderer.sampleRate
        let barFrames = MetronomeBufferRenderer.framesPerBar(tempo: tempo, beats: beatsPerBar)
        let phase = (elapsed * sampleRate).truncatingRemainder(dividingBy: Double(barFrames))
        var beat = 0
        for index in 1..<beatsPerBar where phase >= Double(MetronomeBufferRenderer.beatFrame(index, tempo: tempo)) { beat = index }
        if currentBeat != beat { currentBeat = beat }
    }
    func tap() {
        let time = now()
        guard time.isFinite else { return }
        if let last = taps.last {
            let interval = time - last
            if interval < 0 || interval > 2.5 { taps.removeAll() }
            else if interval < 0.2 { return }
        }
        taps.append(time)
        if taps.count > 5 { taps.removeFirst() }
        if taps.count >= 2, let first = taps.first, let last = taps.last {
            setTempo(Int((60 * Double(taps.count - 1) / (last - first)).rounded()))
        }
    }
    deinit { timer?.invalidate() }
}
