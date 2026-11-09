import Foundation
import AVFoundation
import AudioToolbox

@MainActor
final class ChordAudioPlayer: ChordSoundPlaying {
    enum PlaybackError: LocalizedError {
        case invalidNotes, invalidDuration, missingSoundbank, soundbank(Error), output(Error)
        var errorDescription: String? {
            switch self {
            case .invalidNotes: return "The chord has no playable MIDI notes."
            case .invalidDuration: return "The playback duration must be a positive, finite number."
            case .missingSoundbank: return "The macOS instrument soundbank is unavailable."
            case .soundbank: return "The selected instrument could not be loaded."
            case .output: return "Audio output could not be started. Check your audio device and try again."
            }
        }
    }

    private var engine: AVAudioEngine?
    private var sampler: AVAudioUnitSampler?
    private let offlineSampleRate: Double?
    private let bankURL = URL(fileURLWithPath: "/System/Library/Components/CoreAudio.component/Contents/Resources/gs_instruments.dls")
    private var configured = false
    private var program: UInt8?
    private var activeNotes: [UInt8] = []
    private var stopTask: Task<Void, Never>?
    private var generation: UInt64 = 0

    init() { offlineSampleRate = nil }
    /// Offline mode uses the same sampler, program loading and MIDI path without an audio device.
    init(offlineSampleRate: Double) { self.offlineSampleRate = offlineSampleRate }

    private func configureIfNeeded() throws {
        guard !configured else { return }
        guard FileManager.default.fileExists(atPath: bankURL.path) else { throw PlaybackError.missingSoundbank }
        var description = AudioComponentDescription(componentType: kAudioUnitType_MusicDevice,
                                                    componentSubType: kAudioUnitSubType_Sampler,
                                                    componentManufacturer: kAudioUnitManufacturer_Apple,
                                                    componentFlags: 0, componentFlagsMask: 0)
        guard AudioComponentFindNext(nil, &description) != nil else {
            throw PlaybackError.output(NSError(domain: "ChordAudio", code: 3))
        }
        let engine = AVAudioEngine()
        let sampler = AVAudioUnitSampler()
        engine.attach(sampler)
        engine.connect(sampler, to: engine.mainMixerNode, format: nil)
        if let rate = offlineSampleRate {
            guard let format = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2) else {
                throw PlaybackError.output(NSError(domain: "ChordAudio", code: 1))
            }
            do { try engine.enableManualRenderingMode(.offline, format: format, maximumFrameCount: 4096) }
            catch { throw PlaybackError.output(error) }
        }
        self.engine = engine
        self.sampler = sampler
        configured = true
    }

    func play(notes: [UInt8], instrument: ChordInstrument, volume: Double, duration: Double) throws {
        guard !notes.isEmpty, notes.allSatisfy({ $0 <= 127 }) else { throw PlaybackError.invalidNotes }
        guard duration.isFinite, duration > 0, duration < Double(UInt64.max) / 1_000_000_000 else {
            throw PlaybackError.invalidDuration
        }
        stop()
        try configureIfNeeded()
        guard let engine, let sampler else { throw PlaybackError.output(NSError(domain: "ChordAudio", code: 4)) }
        if program != instrument.midiProgram {
            do {
                try sampler.loadSoundBankInstrument(at: bankURL, program: instrument.midiProgram,
                                                    bankMSB: UInt8(kAUSampler_DefaultMelodicBankMSB),
                                                    bankLSB: UInt8(kAUSampler_DefaultBankLSB))
                program = instrument.midiProgram
            } catch {
                program = nil
                throw PlaybackError.soundbank(error)
            }
        }
        setVolume(volume)
        if !engine.isRunning {
            do { try engine.start() } catch { throw PlaybackError.output(error) }
        }
        activeNotes = Array(Set(notes)).sorted()
        for note in activeNotes { sampler.startNote(note, withVelocity: 90, onChannel: 0) }
        let current = generation
        stopTask = Task { @MainActor [weak self] in
            do { try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000)) }
            catch { return }
            guard let self, self.generation == current else { return }
            self.releaseNotes()
        }
    }

    private func releaseNotes() {
        guard let sampler else { return }
        for note in activeNotes { sampler.stopNote(note, onChannel: 0) }
        activeNotes.removeAll()
        stopTask = nil
    }

    deinit { stopTask?.cancel() }

    func setVolume(_ volume: Double) {
        engine?.mainMixerNode.outputVolume = Float(volume.isFinite ? min(1, max(0, volume)) : 0)
    }

    func stop() {
        generation &+= 1
        stopTask?.cancel()
        stopTask = nil
        guard let sampler else { return }
        for note in activeNotes { sampler.stopNote(note, onChannel: 0) }
        sampler.sendController(120, withValue: 0, onChannel: 0) // All Sound Off, including release tails.
        activeNotes.removeAll()
    }

    /// Used only with the offline initializer; nil for a real-time engine.
    var offlineFormat: AVAudioFormat? { offlineSampleRate == nil || !configured ? nil : engine?.manualRenderingFormat }
    func renderOffline(_ frames: AVAudioFrameCount, into buffer: AVAudioPCMBuffer) throws -> AVAudioEngineManualRenderingStatus {
        guard offlineSampleRate != nil, let engine, engine.isRunning else { throw PlaybackError.output(NSError(domain: "ChordAudio", code: 2)) }
        return try engine.renderOffline(frames, to: buffer)
    }
}
